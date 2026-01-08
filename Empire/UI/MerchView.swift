import SwiftUI

struct MerchView: View {
    let featured: [MerchItem] = [
        MerchItem(name: "Empire Hoodie", price: "$80", imageName: "merch0")
    ]
    
    let bestSellers: [MerchItem] = [
        MerchItem(name: "Empire Tee", price: "$35", imageName: "merch1"),
        MerchItem(name: "Empire Cap", price: "$25", imageName: "merch2"),
        MerchItem(name: "Empire Jacket", price: "$120", imageName: "merch3")
    ]
    
    let newArrivals: [MerchItem] = [
        MerchItem(name: "Empire Socks", price: "$15", imageName: "merch0"),
        MerchItem(name: "Empire Beanie", price: "$30", imageName: "merch1"),
        MerchItem(name: "Empire Sweatpants", price: "$70", imageName: "merch2")
    ]
    
    @State private var query: String = ""
    @State private var showFilters: Bool = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    DashboardHeader(query: $query, showFilters: $showFilters)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    DashboardCard {
                        MarketplaceSection(title: "Featured", items: featured, cardHeight: 320)
                        MarketplaceSection(title: "Best Sellers", items: bestSellers, cardHeight: 260)
                        MarketplaceSection(title: "New Arrivals", items: newArrivals, cardHeight: 260)
                    }
                }
                .padding(.bottom, 40)
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
    @State private var isEditing: Bool = false

    var body: some View {
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
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showFilters.toggle() }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Marketplace Section Card
struct MarketplaceSection: View {
    let title: String
    let items: [MerchItem]
    let cardHeight: CGFloat

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                Badge(text: "See All", color: Color("EmpireMint").opacity(0.9))
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
                        ForEach(items) { item in
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

                    // subtle shine
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

                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                } label: {
                    Text("Buy Now")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 18)
                        .background(
                            LinearGradient(
                                colors: [Color("EmpireMint").opacity(0.85), Color("EmpireMint").opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: Color("EmpireMint").opacity(0.4), radius: 5, x: 0, y: 3)
                        .scaleEffect(isPressed ? 0.95 : 1)
                        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isPressed = pressing }
                        }, perform: {})
                }
            }
            .padding(12)
        }
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

// MARK: - Preview
struct MerchView_Previews: PreviewProvider {
    static var previews: some View {
        MerchView()
            .preferredColorScheme(.dark)
    }
}
