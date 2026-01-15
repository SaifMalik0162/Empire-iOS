import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismissView
    @State private var showSettings = false
    @State private var animateGradient = false
    
    @State private var username: String = ""
    @State private var profileImage: String = "profilePic"
    @State private var badges: [String] = ["badge0", "badge1", "badge2"]
    
    @State private var featuredCards: [String] = ["VIP Perk", "Recent Buy", "Rewards"]
    
    @State private var showAddVehicle: Bool = false
    @StateObject private var vehiclesVM = UserVehiclesViewModel()
    
    // Computed stats placeholder (to be wired to backend later)
    private var computedStats: [(String, Int)] {
        let meetsCount = 0 // TODO: replace with actual meets count from backend/profile
        let carsCount = vehiclesVM.vehicles.count
        let merchCount = 0 // TODO: replace with purchases count later
        return [("Meets", meetsCount), ("Cars", carsCount), ("Merch", merchCount)]
    }
    
    @State private var selectedVehicleIndex = 0
    @State private var featuredIndex: Int = 0
    @State private var isJiggling: Bool = false
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    @State private var avatarURL: URL? = nil
    
    private var displayName: String {
        if let u = authViewModel.currentUser {
            if !u.username.isEmpty {
                return u.username
            }
            if !u.email.isEmpty {
                return u.email
            }
        }
        return username
    }
    
    private func performLogoutNow() {
        print("[ProfileView] 🔘 Logout button tapped")
        print("[ProfileView] Before logout: isAuthenticated=\(authViewModel.isAuthenticated), isLoading=\(authViewModel.isLoading)")
        authViewModel.logout()
        print("[ProfileView] After logout call returned: isAuthenticated=\(authViewModel.isAuthenticated), isLoading=\(authViewModel.isLoading)")
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            Color.clear.frame(width: 0, height: 0).onAppear {
                print("[ProfileView] body recomputed")
            }
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

                            Group {
                                if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                } else if let url = avatarURL {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView().tint(Color("EmpireMint"))
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure:
                                            Image(profileImage).resizable().scaledToFill()
                                        @unknown default:
                                            Image(profileImage).resizable().scaledToFill()
                                        }
                                    }
                                } else {
                                    Image(profileImage)
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                            .frame(width: 92, height: 92)
                            .clipShape(Circle())
                            .overlay(
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Rectangle().fill(Color.clear)
                                }
                                .labelsHidden()
                                .allowsHitTesting(false)
                            )
                        }
                        .onChange(of: selectedPhotoItem) { oldValue, newValue in
                            guard let item = newValue else { return }
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    await MainActor.run { 
                                        selectedImageData = data 
                                    }
                                    // TODO: When API is available, upload avatar to backend here using selectedImageData
                                    // Example:
                                    // try await APIService.shared.uploadAvatar(data: data)
                                }
                            }
                        }

                        Text(displayName)
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
                    .onAppear {
                        // Initialize avatar URL if your BackendUser provides one later
                        // Example: if let urlString = authViewModel.currentUser?.avatarURL { avatarURL = URL(string: urlString) }
                    }
                }
                .padding(.horizontal, 16)
                
                // MARK: - Stats
                HStack(spacing: 12) {
                    ForEach(computedStats, id: \.0) { stat in
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
                                let screenMid = geo.size.width / 2
                                Color.clear
                                    .onAppear { if abs(midX - screenMid) < 120 { featuredIndex = idx } }
                                    .onChange(of: midX) { oldValue, newValue in if abs(newValue - screenMid) < 120 { featuredIndex = idx } }
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
                                if vehiclesVM.vehicles.isEmpty {
                                    Button {
                                        showAddVehicle = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add your first vehicle")
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(Color("EmpireMint"))
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(0.06))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                } else {
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

                                        Image(vehiclesVM.vehicles[selectedVehicleIndex].imageName)
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
                                    .rotationEffect(.degrees(isJiggling ? 1.8 : 0), anchor: .center)
                                    .scaleEffect(isJiggling ? 0.98 : 1.0)
                                    .animation(isJiggling ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default, value: isJiggling)
                                    .onLongPressGesture(minimumDuration: 0.35) {
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.impactOccurred()
                                        isJiggling = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                            isJiggling = false
                                        }
                                        // Present editor if desired in future; for now just jiggle to indicate edit affordance
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(vehiclesVM.vehicles[selectedVehicleIndex].name)
                                            .foregroundColor(.white)
                                            .bold()
                                        if vehiclesVM.vehicles[selectedVehicleIndex].isJailbreak {
                                            Text("Jailbreak")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(Color.purple.opacity(0.18)))
                                                .overlay(Capsule().stroke(Color.purple.opacity(0.6), lineWidth: 1))
                                                .foregroundStyle(.white)
                                        }
                                        
                                        Text(vehiclesVM.vehicles[selectedVehicleIndex].description)
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                }
                            }
                        }
                            .padding(14)
                    )
                    .padding(.horizontal, 16)
                
                // MARK: - Settings
                VStack(spacing: 14) {
                    Button { showSettings = true } label: { GlassOptionRow(icon: "gearshape.fill", title: "Settings") }
                        .buttonStyle(.plain)
                    GlassOptionRow(icon: "questionmark.circle.fill", title: "Help & Support")
                    Button {
                        print("[ProfileView] Haptic + about to call performLogoutNow()")
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                        performLogoutNow()
                    }
                    label: {
                        GlassOptionRow(icon: "arrow.right.square.fill", title: "Log Out", destructive: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(true)
                    .padding(.vertical, 4)
                    .zIndex(1)
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: authViewModel.isAuthenticated) { oldValue, newValue in
                print("[ProfileView] onChange isAuthenticated: old=\(oldValue) -> new=\(newValue)")
            }
            .onAppear {
                print("[ProfileView] onAppear")
                print("[ProfileView] has AuthVM instanceID: \(authViewModel.instanceID)")
                print("[ProfileView] initial isAuthenticated=\(authViewModel.isAuthenticated), isLoading=\(authViewModel.isLoading)")
            }
            .task {
                print("[ProfileView] .task appeared")
            }
            .padding(.top, 16)
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 108)
            }
            .sheet(isPresented: $showSettings) {
                Text("Settings coming soon").padding().preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showAddVehicle) {
                EmpireAddVehicleView(vm: vehiclesVM)
                    .preferredColorScheme(.dark)
            }
            .onAppear {
                Task { await vehiclesVM.loadVehicles() }
            }
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color.black, Color.black.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
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

