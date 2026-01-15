import SwiftUI
import UIKit

// MARK: - Saved Photo Loader (fallback to any uploaded car photo)
private func loadAnySavedCarPhotoData() -> Data? {
    let currentUserId = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
    let defaults = UserDefaults.standard
    // Try scanning for per-user scoped keys first
    let all = defaults.dictionaryRepresentation().keys
    if let key = all.first(where: { $0.hasPrefix("saved_car_photo_\(currentUserId)_") }),
       let data = defaults.data(forKey: key) {
        return data
    }
    // Fallback: legacy keys without user scoping
    if let legacyKey = all.first(where: { $0.hasPrefix("saved_car_photo_") }),
       let data = defaults.data(forKey: legacyKey) {
        return data
    }
    return nil
}

struct HomeView: View {
    // MARK: - Data Sources
    private let featuredMerch: [MerchItem] = [
        MerchItem(name: "Street Royalty Hoodie", price: "$80", imageName: "street_royalty_hoodie", category: .apparel),
        MerchItem(name: "Empire Single Logo Tee", price: "$35", imageName: "empire_single_logo_tee", category: .apparel),
        MerchItem(name: "Air Freshener Kit", price: "$15", imageName: "air_freshener_kit", category: .accessories)
    ]

    private let communityCars: [Car] = [
        Car(name: "Honda Prelude BB2", description: "@officialtobysemple — Clean BB2 build", imageName: "prelude_bb2", horsepower: 450, stage: 3),
        Car(name: "Civic Si Coupe", description: "@fg2_corey — FG2 Si coupe", imageName: "civic_si_fg2", horsepower: 220, stage: 2),
        Car(name: "1968 Mustang", description: "347 Stroker V8", imageName: "68_blaze", horsepower: 350, stage: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background Gradient
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Subtle top glow
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                GeometryReader { geo in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            HomeHeader()
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            // MARK: - Upcoming Meets (Compact & Sleek)
                            GlassCard(height: nil) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Upcoming Meets")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Spacer()
                                        NavigationLink {
                                            MeetsView()
                                        } label: {
                                            Text("See All")
                                                .font(.subheadline)
                                                .foregroundColor(Color("EmpireMint"))
                                        }
                                    }

                                    VStack(spacing: 6) {
                                        ForEach(0..<2) { meet in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Empire Meet \(meet + 1)")
                                                        .font(.subheadline)
                                                        .foregroundColor(.white)
                                                    Text("City · Date")
                                                        .font(.caption2)
                                                        .foregroundColor(.white.opacity(0.6))
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                            Divider().background(Color.white.opacity(0.1))
                                        }
                                    }
                                }
                                .padding(14)
                            }
                            .padding(.horizontal, 16)

                            // MARK: - Featured Cars Carousel
                            HStack {
                                Text("Featured Cars")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                NavigationLink {
                                    CarsView()
                                } label: {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundColor(Color("EmpireMint"))
                                }
                            }
                            .padding(.horizontal, 16)

                            GlassCard(height: 200) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 20) {
                                        // Prepend static first image card: car0
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 150, height: 180)
                                                .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                                                .overlay(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.15), Color.clear, Color.white.opacity(0.05)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                                )

                                            Group {
                                                if let data = loadAnySavedCarPhotoData(), let uiImage = UIImage(data: data) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                } else {
                                                    Image("car0")
                                                        .resizable()
                                                }
                                            }
                                            .scaledToFill()
                                            .frame(width: 150, height: 180)
                                            .cornerRadius(20)
                                            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

                                            LinearGradient(
                                                colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                            .cornerRadius(20)

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
                                            .modifier(HomeCompactShine())
                                        }

                                        ForEach(communityCars.indices, id: \.self) { idx in
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(.ultraThinMaterial)
                                                    .frame(width: 150, height: 180)
                                                    .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                                                    .overlay(
                                                        LinearGradient(
                                                            colors: [Color.white.opacity(0.15), Color.clear, Color.white.opacity(0.05)],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                                    )

                                                Image(communityCars[idx].imageName)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 150, height: 180)
                                                    .cornerRadius(20)
                                                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

                                                LinearGradient(
                                                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                                .cornerRadius(20)

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
                                                .modifier(HomeCompactShine())
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.leading, 16)
                                    .padding(.trailing, 60)
                                }
                            }
                            .padding(.horizontal, 16)

                            Text("Swipe →")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.leading, 24)

                            // MARK: - Empire Merch Preview
                            GlassCard(height: 140) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Empire Merch")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Spacer()
                                        NavigationLink {
                                            MerchView()
                                        } label: {
                                            Text("See All")
                                                .font(.subheadline)
                                                .foregroundColor(Color("EmpireMint"))
                                        }
                                    }
                                    Text("Shop the latest drops")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))

                                    HStack(spacing: 16) {
                                        ForEach(Array(featuredMerch.prefix(3)).indices, id: \.self) { i in
                                            let item = featuredMerch[i]
                                            ZStack {
                                                // Card base
                                                RoundedRectangle(cornerRadius: 18)
                                                    .fill(.ultraThinMaterial)
                                                    .frame(width: 100, height: 100)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 18)
                                                            .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                                            .blendMode(.screen)
                                                    )
                                                    .shadow(color: Color("EmpireMint").opacity(0.25), radius: 8, y: 3)
                                                    .overlay(HomeShimmerOverlay().clipShape(RoundedRectangle(cornerRadius: 18)))

                                                // Full-bleed merch image
                                                Image(item.imageName)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                                    .opacity(0.9)
                                                    .overlay(
                                                        LinearGradient(
                                                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                                    )
                                                    .overlay(
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
                                                        .blur(radius: 6)
                                                        .rotationEffect(.degrees(16))
                                                    )

                                                // Bottom caption overlay
                                                VStack {
                                                    Spacer()
                                                    Text(item.name)
                                                        .font(.caption2.weight(.semibold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.center)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 4)
                                                        .background(Color.black.opacity(0.25))
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                        .padding(6)
                                                }
                                                .frame(width: 100, height: 100)
                                            }
                                        }
                                    }
                                }
                                .padding()
                            }
                            .padding(.horizontal, 16)

                            Spacer(minLength: 40)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
}

// MARK: — Glass Card Component
struct GlassCard<Content: View>: View {
    let height: CGFloat?
    let content: Content

    init(height: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.height = height
        self.content = content()
    }

    var body: some View {
        VStack {
            content
        }
        .frame(maxWidth: .infinity, minHeight: height ?? 0)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.screen)
                HomeShimmerOverlay().clipShape(RoundedRectangle(cornerRadius: 24))
            }
        )
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.5), radius: 18, y: 6)
    }
}

// MARK: - Home Header
private struct HomeHeader: View {
    @State private var query: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Welcome back")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 10) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "bell").foregroundStyle(.white))
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "gearshape").foregroundStyle(.white))
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
            }
        }
    }
}

// MARK: - Shimmer Helpers
private struct HomeShimmerOverlay: View {
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
        .onAppear { withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) { phase = 1 } }
        .blendMode(.screen)
        .opacity(0.5)
        .allowsHitTesting(false)
    }
}

private struct HomeCompactShine: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .opacity(0.5)
            .offset(x: phase * 160, y: phase * 80)
            .onAppear {
                phase = -1
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) { phase = 1.2 }
            }
            .allowsHitTesting(false)
    }
}
