import SwiftUI

struct RecentBuyView: View {
    @Environment(\.dismiss) private var dismiss

    // Input model from Merch
    var item: MerchItem
    // Optional order metadata (placeholder until backend is wired)
    var variant: String? = nil
    var orderDate: String? = nil
    var status: String? = nil

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 320)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // Header card
                    ZStack {
                        glassCard(cornerRadius: 28)
                        VStack(spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: "bag.fill")
                                    .foregroundStyle(Color("EmpireMint"))
                                    .font(.system(size: 20, weight: .bold))
                                Text("Recent Buy")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(status ?? "Completed")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(.ultraThinMaterial))
                                    .overlay(Capsule().stroke(gradientStroke, lineWidth: 1))
                            }

                            HStack(alignment: .center, spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 96, height: 96)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gradientStroke, lineWidth: 1))
                                    Image(item.imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 96)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.name)
                                        .font(.headline.bold())
                                        .foregroundStyle(.white)
                                    if let variant {
                                        Text(variant)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    if let orderDate {
                                        HStack(spacing: 8) {
                                            Image(systemName: "calendar").foregroundStyle(Color("EmpireMint"))
                                            Text(orderDate)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.75))
                                        }
                                    }
                                    HStack(spacing: 8) {
                                        Image(systemName: "dollarsign").foregroundStyle(Color("EmpireMint"))
                                        Text(item.price)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(18)
                    }
                    .padding(.horizontal, 16)

                    // Recent items list (optional)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Items")
                            .font(.headline)
                            .foregroundStyle(.white)

                        let metalBanner = (MerchCatalog.bestSellers.first { $0.name == "Metal Banner" }) ?? MerchItem(name: "Metal Banner", price: "$25", imageName: "metal_banner", category: .banners)
                        let sampleItems: [MerchItem] = [
                            item,
                            metalBanner
                        ]
                        ForEach(Array(sampleItems.enumerated()), id: \.offset) { idx, merch in
                            itemRow(name: merch.name, subtitle: merch.category.rawValue, price: merch.price, imageName: merch.imageName)
                        }
                    }
                    .padding(16)
                    .background(glassCard(cornerRadius: 22))
                    .padding(.horizontal, 16)

                    Text("Orders and item details are in progress. This view will update as we process your order.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                .padding(.top, 16)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 60)
                }
            }
        }
        .navigationTitle("Recent Buy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews & helpers

    private var gradientStroke: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func glassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(gradientStroke, lineWidth: 1)
                    .blendMode(.screen)
            )
            .shadow(color: Color("EmpireMint").opacity(0.2), radius: 12, y: 6)
    }

    private func itemRow(name: String, subtitle: String, price: String, imageName: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(gradientStroke, lineWidth: 1))
                .overlay(
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .foregroundStyle(.white)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Text(price)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .overlay(Capsule().stroke(gradientStroke, lineWidth: 1))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(gradientStroke, lineWidth: 1))
    }
}

#Preview {
    RecentBuyView(item: MerchItem(name: "Empire Hoodie", price: "$78.00", imageName: "hoodiePlaceholder", category: .apparel), variant: "Black / L", orderDate: "Jan 12, 2026", status: "Shipped")
}
