import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject private var cart: Cart
    let item: MerchItem
    let related: [MerchItem]

    @State private var quantity: Int = 1

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

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    cart.add(item, quantity: quantity)
                } label: {
                    HStack {
                        Image(systemName: "cart.badge.plus")
                        Text("Add to Cart")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color("EmpireMint").opacity(0.85), Color("EmpireMint").opacity(0.55)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color("EmpireMint").opacity(0.4), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

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
    }
}
