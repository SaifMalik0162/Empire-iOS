import SwiftUI

struct MerchView: View {
    let featured: [MerchItem] = [
        MerchItem(name: "Street Royalty Hoodie", price: "$80", imageName: "street_royalty_hoodie", category: .apparel),
        MerchItem(name: "Empire Single Logo Tee", price: "$35", imageName: "empire_single_logo_tee", category: .apparel),
        MerchItem(name: "Air Freshener Kit", price: "$15", imageName: "air_freshener_kit", category: .accessories)
    ]
    
    let bestSellers: [MerchItem] = [
        MerchItem(name: "Classic Banner", price: "$25", imageName: "classic_banner", category: .banners),
        MerchItem(name: "Death Metal Banner", price: "$25", imageName: "death_metal_banner", category: .banners),
        MerchItem(name: "Metal Banner", price: "$25", imageName: "metal_banner", category: .banners),
        MerchItem(name: "Urban Banner", price: "$25", imageName: "urban_banner", category: .banners)
    ]
    
    let newArrivals: [MerchItem] = [
        MerchItem(name: "Astro Banner", price: "$25", imageName: "astro_banner", category: .banners),
        MerchItem(name: "Empire™ Banner", price: "$25", imageName: "empiretm_banner", category: .banners),
        MerchItem(name: "Mini Banner", price: "$20", imageName: "mini_banner", category: .banners),
        MerchItem(name: "Tribal Flames Banner", price: "$25", imageName: "tribal_flames_banner", category: .banners),
        MerchItem(name: "Empire Tsurikawa", price: "$30", imageName: "empire_tsurikawa", category: .accessories),
        MerchItem(name: "Civic Decal", price: "$12", imageName: "civic_decal", category: .banners),
        MerchItem(name: "i-VTEC Decal", price: "$12", imageName: "i-vtec_decal", category: .banners)
    ]
    
    @State private var query: String = ""
    @State private var showFilters: Bool = false
    @State private var selectedCategory: MerchCategory? = nil
    @State private var showToast: Bool = false
    @State private var toastTitle: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        DashboardHeader(query: $query, showFilters: $showFilters, selectedCategory: $selectedCategory)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        DashboardCard {
                            if selectedCategory == nil {
                                MarketplaceSection(title: "Featured", items: featured, cardHeight: 320, categoryFilter: selectedCategory)
                                MarketplaceSection(title: "Best Sellers", items: bestSellers, cardHeight: 260, categoryFilter: selectedCategory)
                                MarketplaceSection(title: "New Arrivals", items: newArrivals, cardHeight: 260, categoryFilter: selectedCategory)
                            } else {
                                let allItems = featured + bestSellers + newArrivals
                                switch selectedCategory {
                                case .apparel?:
                                    MarketplaceSection(title: MerchCategory.apparel.rawValue, items: allItems.filter { $0.category == .apparel }, cardHeight: 260, categoryFilter: selectedCategory)
                                case .accessories?:
                                    MarketplaceSection(title: MerchCategory.accessories.rawValue, items: allItems.filter { $0.category == .accessories }, cardHeight: 260, categoryFilter: selectedCategory)
                                case .banners?:
                                    MarketplaceSection(title: MerchCategory.banners.rawValue, items: allItems.filter { $0.category == .banners }, cardHeight: 260, categoryFilter: selectedCategory)
                                case nil:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Dashboard Shell
private struct DashboardCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 18) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                        .blendMode(.screen)
                )
                .shadow(color: Color("EmpireMint").opacity(0.22), radius: 24, x: 0, y: 14)
        )
        .padding(.horizontal, 16)
    }
}

private struct DashboardHeader: View {
    @Binding var query: String
    @Binding var showFilters: Bool
    @Binding var selectedCategory: MerchCategory?
    @EnvironmentObject private var cart: Cart
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.8))
                    TextField("Search merch", text: $query)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    NavigationLink {
                        CartView()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "cart")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Circle().fill(.ultraThinMaterial))
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            
                            // Badge
                            let totalQty = cart.items.reduce(0) { $0 + $1.quantity }
                            if totalQty > 0 {
                                Text("\(totalQty)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color("EmpireMint"))
                                    .clipShape(Capsule())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedCategory = nil }
                }
                CategoryChip(title: MerchCategory.apparel.rawValue, isSelected: selectedCategory == .apparel) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedCategory = .apparel }
                }
                CategoryChip(title: MerchCategory.accessories.rawValue, isSelected: selectedCategory == .accessories) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedCategory = .accessories }
                }
                CategoryChip(title: MerchCategory.banners.rawValue, isSelected: selectedCategory == .banners) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedCategory = .banners }
                }
            }
        }
    }
}

// MARK: - Marketplace Section Card
struct MarketplaceSection: View {
    let title: String
    let items: [MerchItem]
    let cardHeight: CGFloat
    let categoryFilter: MerchCategory?

    var body: some View {
        let filtered = categoryFilter == nil ? items : items.filter { $0.category == categoryFilter }

        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                NavigationLink {
                    MerchGridView(title: title, items: filtered, categoryFilter: categoryFilter)
                } label: {
                    Badge(text: "See All", color: Color("EmpireMint").opacity(0.9))
                }
            }
            .padding(.horizontal, 12)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .blendMode(.screen)
                    )
                    .shadow(color: Color("EmpireMint").opacity(0.18), radius: 16, x: 0, y: 8)
                    .overlay(CompactShimmerOverlay().clipShape(RoundedRectangle(cornerRadius: 24)))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(filtered) { item in
                            MarketplaceItemCard(item: item, width: 180, height: cardHeight - 60)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(height: cardHeight)
    }
}

// MARK: - Marketplace Item Card
struct MarketplaceItemCard: View {
    let item: MerchItem
    let width: CGFloat
    let height: CGFloat
    @State private var isPressed: Bool = false

    var body: some View {
        NavigationLink {
            ProductDetailView(item: item, related: [])
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: width, height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                            .blendMode(.screen)
                    )
                    .shadow(color: Color("EmpireMint").opacity(0.2), radius: 10, x: 0, y: 4)

                VStack(spacing: 10) {
                    ZStack {
                        Image(item.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width - 24, height: height * 0.56)
                            .cornerRadius(18)
                            .opacity(0.85)

                        LinearGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .cornerRadius(18)

                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white.opacity(0.18), location: 0.5),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)
                        .opacity(0.22)
                        .blur(radius: 8)
                        .rotationEffect(.degrees(16))
                        .modifier(CompactShine())
                    }
                    .shadow(color: Color("EmpireMint").opacity(0.35), radius: 6, x: 0, y: 3)

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
                    }
                }
                .padding(12)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subtle Shimmer & Badge
private struct CompactShimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .offset(x: phase * 160, y: phase * 60)
            .onAppear {
                phase = -1
                withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
            .onDisappear { phase = -1 }
            .allowsHitTesting(false)
            .clipped()
    }
}

private struct CompactShine: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .opacity(0.5)
            .offset(x: phase * 160, y: phase * 80)
            .onAppear {
                phase = -1
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
            .allowsHitTesting(false)
    }
}

private struct CompactShimmerOverlay: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white.opacity(0.25), location: 0.45),
                .init(color: .clear, location: 0.9)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .scaleEffect(x: 1.6)
        .offset(x: -120 + phase * 240)
        .onAppear {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) { phase = 1 }
        }
        .blendMode(.screen)
        .opacity(0.5)
        .allowsHitTesting(false)
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color.opacity(0.18))
            )
            .overlay(
                Capsule().stroke(color.opacity(0.6), lineWidth: 1)
            )
            .foregroundStyle(.white)
    }
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? Color("EmpireMint").opacity(0.25) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color("EmpireMint").opacity(0.9) : Color.white.opacity(0.25), lineWidth: 1)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
struct MerchView_Previews: PreviewProvider {
    static var previews: some View {
        MerchView()
            .preferredColorScheme(.dark)
    }
}
