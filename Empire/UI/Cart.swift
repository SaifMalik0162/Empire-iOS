import Foundation
import Combine 
import SwiftUI

struct CartItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    let item: MerchItem
    var selectedSize: String? = nil
    var quantity: Int

    static func == (lhs: CartItem, rhs: CartItem) -> Bool {
        return lhs.id == rhs.id && lhs.item.id == rhs.item.id && lhs.selectedSize == rhs.selectedSize && lhs.quantity == rhs.quantity
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(item.id)
        hasher.combine(selectedSize)
        hasher.combine(quantity)
    }
}

@MainActor
final class Cart: ObservableObject {
    @Published private(set) var items: [CartItem] = []
    @Published var lastAddedItemName: String? = nil
    private var toastClearTask: Task<Void, Never>? = nil

    func add(_ item: MerchItem, quantity: Int = 1, selectedSize: String? = nil) {
        if let idx = items.firstIndex(where: { $0.item.id == item.id && $0.selectedSize == selectedSize }) {
            items[idx].quantity += quantity
        } else {
            items.append(CartItem(item: item, selectedSize: selectedSize, quantity: quantity))
        }
        lastAddedItemName = item.name
        toastClearTask?.cancel()
        toastClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { self?.lastAddedItemName = nil }
        }
    }

    func remove(_ cartItem: CartItem) {
        items.removeAll { $0.id == cartItem.id }
    }

    func updateQuantity(_ cartItem: CartItem, quantity: Int) {
        guard let idx = items.firstIndex(where: { $0.id == cartItem.id }) else { return }
        let newQty = max(1, quantity)
        items[idx].quantity = newQty
    }

    func clear() {
        items.removeAll()
    }

    var subtotal: Decimal {
        items.reduce(0) { partial, cartItem in
            let price = Decimal(string: cartItem.item.price.replacingOccurrences(of: "$", with: "")) ?? 0
            return partial + price * Decimal(cartItem.quantity)
        }
    }

    var tax: Decimal { subtotal * 0.08 }
    var shipping: Decimal { items.isEmpty ? 0 : 5 }
    var total: Decimal { subtotal + tax + shipping }
}

