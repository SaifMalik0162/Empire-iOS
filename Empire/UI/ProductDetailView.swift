import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject private var cart: Cart
    let item: MerchItem
    let related: [MerchItem]

    @State private var quantity: Int = 1
    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var selectedSize: String? = nil
    private let sizes = ["S", "M", "L", "XL", "XXL"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)
                    .shadow(color: Color("EmpireMint").opacity(0.3), radius: 12, x: 0, y: 6)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(item.price)
                            .font(.headline)
                            .foregroundStyle(Color("EmpireMint"))
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    Text("Quantity")
                        .foregroundStyle(.white.opacity(0.9))
                    Stepper(value: $quantity, in: 1...10) {
                        Text("\(quantity)")
                            .foregroundStyle(.white)
                    }
                    .tint(Color("EmpireMint"))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("A premium item from Empire with top-notch materials and design aesthetics. Perfect for fans and collectors.")
                        .foregroundStyle(.white.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Availability")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("In Stock")
                        .foregroundStyle(.white.opacity(0.8))
                }

                if item.category == .apparel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Size")
                            .font(.headline)
                            .foregroundStyle(.white)
                        HStack(spacing: 8) {
                            ForEach(sizes, id: \.self) { size in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        selectedSize = size
                                    }
                                } label: {
                                    Text(size)
                                        .font(.subheadline.weight(.semibold))
                                        .frame(minWidth: 44)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(selectedSize == size ? Color("EmpireMint").opacity(0.25) : Color.white.opacity(0.08))
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(selectedSize == size ? Color("EmpireMint").opacity(0.9) : Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    guard item.category != .apparel || selectedSize != nil else { return }
                    cart.add(item, quantity: quantity, selectedSize: selectedSize)
                    toastText = "Added \"\(item.name)\" to cart"
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeInOut(duration: 0.25)) { showToast = false }
                    }
                } label: {
                    HStack {
                        Image(systemName: "cart.badge.plus")
                        Text(item.category == .apparel && selectedSize == nil ? "Select Size" : "Add to Cart")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color("EmpireMint").opacity((item.category == .apparel && selectedSize == nil) ? 0.45 : 0.85), Color("EmpireMint").opacity((item.category == .apparel && selectedSize == nil) ? 0.30 : 0.55)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .cornerRadius(14)
                    .shadow(color: Color("EmpireMint").opacity((item.category == .apparel && selectedSize == nil) ? 0.2 : 0.4), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .disabled(item.category == .apparel && selectedSize == nil)

                if !related.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Related Items")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(related) { r in
                                    NavigationLink {
                                        ProductDetailView(item: r, related: related.filter { $0.id != r.id })
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(r.imageName)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 90)
                                                .clipped()
                                                .cornerRadius(10)
                                            Text(r.name)
                                                .font(.caption.bold())
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showToast {
                TopToast(text: toastText)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    .padding(.top, 8)
            }
        }
    }
}

