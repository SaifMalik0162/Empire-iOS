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
                        .shadow(color: Color("EmpireMint").opacity(0.25), radius: 14, y: 8)
                    
                    VStack(spacing: 10) {
                        Image(profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 92, height: 92)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color("EmpireMint").opacity(0.6), lineWidth: 2)
                            )
                            .shadow(color: Color("EmpireMint").opacity(0.7), radius: 6)
                        
                        Text(username)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        Text("@saifm")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.65))
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
                        ForEach(featuredCards, id: \.self) { card in
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
                                    .shadow(color: Color("EmpireMint").opacity(0.25), radius: 10, y: 6)
                                
                                Text(card)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            .frame(width: 180, height: 100)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
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
                                Image(vehicles[selectedVehicleIndex].imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 60)
                                    .cornerRadius(14)
                                
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
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }
}
