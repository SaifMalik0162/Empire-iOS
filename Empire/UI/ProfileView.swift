import SwiftUI

struct ProfileView: View {
    @State private var username: String = "Saif Malik"
    @State private var profileImage: String = "profilePic"
    @State private var badges: [String] = ["badge0", "badge1", "badge2"]
    
    @State private var featuredCards: [String] = ["VIP Perk", "Recent Buy", "Rewards"]
    
    @State private var stats: [(String, Int)] = [
        ("Meets", 12),
        ("Cars", 1),
        ("Merch", 5)
    ]
    
    @State private var vehicles: [Car] = [
        Car(name: "Honda Accord", description: "Luh RS7", imageName: "car0", horsepower: 240, stage: 1)
    ]
    
    @State private var selectedVehicleIndex = 0
    @State private var featuredIndex: Int = 0
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                
                // MARK: - Profile Header
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ), lineWidth: 1
                                )
                                .blendMode(.screen)
                        )
                        .overlay(ProfileShimmer().clipShape(RoundedRectangle(cornerRadius: 28)).opacity(0.4))
                        .shadow(color: Color("EmpireMint").opacity(0.2), radius: 12, y: 6)

                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Circle()
                                        .stroke(LinearGradient(colors: [Color("EmpireMint").opacity(0.8), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                                )
                                .shadow(color: Color("EmpireMint").opacity(0.5), radius: 8)

                            Image(profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 92, height: 92)
                                .clipShape(Circle())
                        }

                        Text(username)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("@saifm")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.65))

                        HStack(spacing: 10) {
                            ProfileChip(systemName: "bell")
                            ProfileChip(systemName: "gearshape")
                            ProfileChip(systemName: "ellipsis")
                        }
                        .padding(.top, 4)
                    }
                    .padding(18)
                }
                .padding(.horizontal, 16)
                
                // MARK: - Stats
                HStack(spacing: 12) {
                    ForEach(stats, id: \.0) { stat in
                        ProfileStatCard(title: stat.0, value: "\(stat.1)")
                    }
                }
                .padding(.horizontal, 16)
                
                // MARK: - Featured
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(featuredCards.enumerated()), id: \.offset) { idx, card in
                            GeometryReader { geo in
                                let midX = geo.frame(in: .global).midX
                                let screenMid = UIScreen.main.bounds.width / 2
                                Color.clear
                                    .onAppear { if abs(midX - screenMid) < 120 { featuredIndex = idx } }
                                    .onChange(of: midX) { _ in if abs(midX - screenMid) < 120 { featuredIndex = idx } }
                                ZStack {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 22)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color("EmpireMint").opacity(0.5),
                                                            Color.clear
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(color: Color("EmpireMint").opacity(0.2), radius: 10, y: 6)
                                        .overlay(ProfileShimmer().clipShape(RoundedRectangle(cornerRadius: 22)))

                                    Text(card)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                }
                                .frame(width: 200, height: 110)
                            }
                            .frame(width: 200, height: 110)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 48)
                }
                
                HStack(spacing: 6) {
                    ForEach(0..<featuredCards.count, id: \.self) { i in
                        Circle()
                            .fill(i == featuredIndex ? Color("EmpireMint").opacity(0.9) : Color.white.opacity(0.3))
                            .frame(width: i == featuredIndex ? 7 : 6, height: i == featuredIndex ? 7 : 6)
                            .animation(.easeInOut(duration: 0.2), value: featuredIndex)
                    }
                }
                .padding(.top, -4)
                
                // MARK: - Vehicle
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color("EmpireMint").opacity(0.6),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color("EmpireMint").opacity(0.3), radius: 14, y: 8)
                    .frame(height: 140)
                    .overlay(
                        VStack(spacing: 10) {
                            HStack {
                                Text("My Vehicle")
                                    .foregroundColor(.white)
                                    .font(.headline.bold())
                                Spacer()
                            }
                            
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 120, height: 84)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                                .blendMode(.screen)
                                        )
                                        .clipped()

                                    Image(vehicles[selectedVehicleIndex].imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 84)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))

                                    LinearGradient(
                                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.25)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(width: 120, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))

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
                                    .opacity(0.18)
                                    .blur(radius: 6)
                                    .rotationEffect(.degrees(16))
                                    .frame(width: 120, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vehicles[selectedVehicleIndex].name)
                                        .foregroundColor(.white)
                                        .bold()
                                    
                                    Text(vehicles[selectedVehicleIndex].description)
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                        }
                            .padding(14)
                    )
                    .padding(.horizontal, 16)
                
                // MARK: - Settings
                VStack(spacing: 14) {
                    GlassOptionRow(icon: "gearshape.fill", title: "Settings")
                    GlassOptionRow(icon: "questionmark.circle.fill", title: "Help & Support")
                    GlassOptionRow(icon: "arrow.right.square.fill", title: "Log Out", destructive: true)
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 108)
            }
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color.black, Color.black.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    Circle()
                        .fill(Color("EmpireMint").opacity(0.12))
                        .frame(width: 420)
                        .blur(radius: 100)
                        .offset(x: -140, y: -280)
                        .blendMode(.plusLighter)

                    Circle()
                        .fill(Color.cyan.opacity(0.08))
                        .frame(width: 520)
                        .blur(radius: 130)
                        .offset(x: 180, y: -320)
                        .blendMode(.plusLighter)

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.2)
                        .ignoresSafeArea()
                }
            )
        }
    }
}

private struct ProfileShimmer: View {
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

private struct ProfileChip: View {
    let systemName: String
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 32, height: 32)
            .overlay(Image(systemName: systemName).foregroundStyle(.white))
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }
}
