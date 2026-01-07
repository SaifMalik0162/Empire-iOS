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
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                
                MarketplaceSection(title: "Featured", items: featured, cardHeight: 320)
                MarketplaceSection(title: "Best Sellers", items: bestSellers, cardHeight: 260)
                MarketplaceSection(title: "New Arrivals", items: newArrivals, cardHeight: 260)
                
                Spacer(minLength: 40)
            }
            .padding(.vertical, 20)
        }
        .background(
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Marketplace Section Card
struct MarketplaceSection: View {
    let title: String
    let items: [MerchItem]
    let cardHeight: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [Color("EmpireMint").opacity(0.6), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color("EmpireMint").opacity(0.2), radius: 12, x: 0, y: 4)
            
            VStack(alignment: .leading, spacing: 12) {
                // Section title
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .shadow(color: Color("EmpireMint").opacity(0.7), radius: 2)
                    .padding(.top, 16)
                    .padding(.leading, 16)
                
                // Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(items) { item in
                            MarketplaceItemCard(item: item, width: 180, height: cardHeight - 60)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .padding(.horizontal, 16)
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color("EmpireMint").opacity(0.6), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color("EmpireMint").opacity(0.25), radius: 10, x: 0, y: 4)
            
            VStack(spacing: 8) {
                ZStack {
                    Image(item.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width - 32, height: height * 0.55)
                        .cornerRadius(20)
                    
                    // Gradient overlay
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .cornerRadius(20)
                }
                .shadow(color: Color("EmpireMint").opacity(0.5), radius: 6, x: 0, y: 3)
                
                VStack(spacing: 2) {
                    Text(item.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(item.price)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Button {
                    print("Buy \(item.name)")
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
                            withAnimation(.spring()) { isPressed = pressing }
                        }, perform: {})
                }
            }
            .padding(12)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Preview
struct MerchView_Previews: PreviewProvider {
    static var previews: some View {
        MerchView()
            .preferredColorScheme(.dark)
    }
}
