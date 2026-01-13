import SwiftUI

struct CartView: View {
    @EnvironmentObject private var cart: Cart
    @State private var showingCheckoutAlert = false
    @State private var checkoutProvider: CheckoutProvider?

    enum CheckoutProvider: String, Identifiable {
        case applePay = "Apple Pay"
        case shopify = "Shopify"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            if cart.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cart")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Your cart is empty")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Add items from the merch catalog to proceed to checkout.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(gradient)
            } else {
                List {
                    Section {
                        ForEach(cart.items) { cartItem in
                            HStack(spacing: 12) {
                                Image(cartItem.item.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 48)
                                    .clipped()
                                    .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cartItem.item.name)
                                        .font(.subheadline.bold())
                                    Text(cartItem.item.price)
                                        .font(.caption)
                                        .foregroundStyle(Color("EmpireMint"))
                                }
                                Spacer()
                                Stepper(value: Binding(
                                    get: { cartItem.quantity },
                                    set: { cart.updateQuantity(cartItem, quantity: $0) }
                                ), in: 1...10) {
                                    Text("\(cartItem.quantity)")
                                }
                                .labelsHidden()
                            }
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let toRemove = cart.items[index]
                                cart.remove(toRemove)
                            }
                        }
                    }

                    Section("Summary") {
                        SummaryRow(label: "Subtotal", value: cart.subtotal)
                        SummaryRow(label: "Tax (est.)", value: cart.tax)
                        SummaryRow(label: "Shipping", value: cart.shipping)
                        SummaryRow(label: "Total", value: cart.total, bold: true)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(gradient)

                VStack(spacing: 10) {
                    Button {
                        checkoutProvider = .applePay
                        showingCheckoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Pay with Apple Pay")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button {
                        checkoutProvider = .shopify
                        showingCheckoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "cart")
                            Text("Checkout with Shopify")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("EmpireMint"))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Cart")
        .navigationBarTitleDisplayMode(.inline)
        .alert(checkoutProvider?.rawValue ?? "Checkout", isPresented: $showingCheckoutAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This is a mock checkout flow. We’ll integrate \(checkoutProvider?.rawValue ?? "your provider") soon.")
        }
    }

    private var gradient: some View {
        LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

private struct SummaryRow: View {
    let label: String
    let value: Decimal
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.formatted(.currency(code: "CAD")))
                .font(bold ? .headline : .body)
        }
        .foregroundStyle(.white)
    }
}
