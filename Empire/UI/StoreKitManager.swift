import Foundation
import Combine
import StoreKit
import SwiftUI

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    // Configure your product identifier
    let vipProductID: String = "com.empireautoclub.empireconnect.vip"

    @Published var isVIP: Bool = false
    @Published var loading: Bool = false
    @Published var purchaseInFlight: Bool = false
    @Published var errorMessage: String? = nil
    @Published var products: [Product] = []

    private init() {
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
        Task {
            // Use a local strong reference to the shared manager to avoid capturing self across concurrency boundaries
            let manager = StoreKitManager.shared
            for await update in StoreKit.Transaction.updates {
                do {
                    let transaction = try await manager.verify(update)
                    await transaction.finish()
                    if transaction.productID == manager.vipProductID {
                        await manager.refreshEntitlements()
                    }
                } catch {
                    await MainActor.run { manager.errorMessage = error.localizedDescription }
                }
            }
        }
    }

    func loadProducts() async {
        if !products.isEmpty { return }
        loading = true
        defer { loading = false }
        do {
            let storeProducts = try await Product.products(for: [vipProductID])
            products = storeProducts
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchaseVIP() async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            if products.isEmpty { await loadProducts() }
            guard let product = products.first(where: { $0.id == vipProductID }) else { return }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try await verify(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        loading = true
        defer { loading = false }
        do {
            for await entitlement in StoreKit.Transaction.currentEntitlements {
                let transaction = try await verify(entitlement)
                if transaction.productID == vipProductID {
                    await transaction.finish()
                }
            }
            await refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        do {
            var active = false
            for await entitlement in StoreKit.Transaction.currentEntitlements {
                if let t = try? await verify(entitlement) {
                    if t.productID == vipProductID, Self.isActive(transaction: t) {
                        active = true
                    }
                }
            }
            isVIP = active
        }
    }

    static func isActive(transaction: StoreKit.Transaction) -> Bool {
        if transaction.revocationDate != nil { return false }
        if let exp = transaction.expirationDate { return exp > Date() }
        return true // non-consumable or non-expiring
    }

    private func verify(_ result: StoreKit.VerificationResult<StoreKit.Transaction>) async throws -> StoreKit.Transaction {
        switch result {
        case .unverified:
            throw NSError(domain: "StoreKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"])
        case .verified(let safe):
            return safe
        }
    }
}
