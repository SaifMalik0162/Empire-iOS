import Foundation
import Combine 
import SwiftUI

struct CartItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    let item: MerchItem
    var quantity: Int

    static func == (lhs: CartItem, rhs: CartItem) -> Bool {
        return lhs.id == rhs.id && lhs.item.id == rhs.item.id && lhs.quantity == rhs.quantity
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(item.id)
        hasher.combine(quantity)
    }
}

@MainActor
final class Cart: ObservableObject {
    @Published private(set) var items: [CartItem] = []

    func add(_ item: MerchItem, quantity: Int = 1) {
        if let idx = items.firstIndex(where: { $0.item.id == item.id }) {
            items[idx].quantity += quantity
        } else {
            items.append(CartItem(item: item, quantity: quantity))
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

