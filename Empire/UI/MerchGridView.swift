import SwiftUI

struct MerchGridView: View {
    let title: String
    let items: [MerchItem]
    var categoryFilter: MerchCategory? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        let filtered = categoryFilter == nil ? items : items.filter { $0.category == categoryFilter }
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filtered) { item in
                    MerchGridCard(item: item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

private struct MerchGridCard: View {
    let item: MerchItem

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                            .blendMode(.screen)
                    )
                    .shadow(color: Color("EmpireMint").opacity(0.18), radius: 10, x: 0, y: 6)

                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                    .blendMode(.screen)
                            )
                            .overlay(
                                Image(item.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .aspectRatio(4.0/3.0, contentMode: .fit)
                    }

                    VStack(spacing: 2) {
                        Text(item.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                        Text(item.price)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Text("Buy Now")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 18)
                            .background(
                                LinearGradient(colors: [Color("EmpireMint").opacity(0.85), Color("EmpireMint").opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(14)
                            .shadow(color: Color("EmpireMint").opacity(0.4), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(minHeight: 220)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MerchGridView(title: "Featured", items: [
            MerchItem(name: "Street Royalty Hoodie", price: "$80", imageName: "street_royalty_hoodie", category: .apparel),
            MerchItem(name: "Empire Single Logo Tee", price: "$35", imageName: "empire_single_logo_tee", category: .apparel),
            MerchItem(name: "Air Freshener Kit", price: "$15", imageName: "air_freshener_kit", category: .accessories)
        ])
    }
}
