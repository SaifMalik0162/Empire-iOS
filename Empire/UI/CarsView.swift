import SwiftUI
import UIKit
import SwiftData
import Combine

struct CarsView: View {
    // MARK: - User's cars
    @StateObject private var userVehiclesVM = UserVehiclesViewModel()
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAddVehicle: Bool = false
    @State private var editingIndex: Int? = nil
    @State private var showVehicleEditor: Bool = false
    @State private var userKey: String = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
    @State private var showQuickMods: Bool = false
    @State private var showQuickSpecs: Bool = false
    @State private var currentGarageIndex: Int = 0
    @State private var showManageGarage: Bool = false

    // MARK: - Community feed
    @StateObject private var communityVM = CommunityViewModel()
    @State private var showShareToFeed: Bool = false
    @State private var shareSuccessToast: String? = nil
    @State private var showShareSuccessToast: Bool = false

    // MARK: - Explore / lightbox
    @State private var selectedCarIndex: Int? = nil
    @Namespace private var ns
    @State private var ripple: Bool = false
    @State private var showLightbox: Bool = false
    @State private var lightboxIndex: Int = 0
    @State private var selectedCommunityIndex: Int? = nil
    @State private var likedCommunity: Set<UUID> = []
    @State private var showSpecsPopup: Bool = false
    @State private var showModsPopup: Bool = false
    @State private var showExploreFeed: Bool = false

    var body: some View {
        ZStack {
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {

                    if userVehiclesVM.vehicles.isEmpty {
                        Button {
                            if let idx = userVehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                                editingIndex = idx
                                showVehicleEditor = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add your first vehicle")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color("EmpireMint"))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    } else {
                        userCarousel
                    }
                    communitySection
                }
                .padding(.vertical, 6)
                .padding(.bottom, 40)
            }

            // MARK: - Expanded user car overlay
            if let selected = selectedCarIndex, userVehiclesVM.vehicles.indices.contains(selected) {
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            selectedCarIndex = nil
                        }
                    }

                CarExpandedCardInline(
                    car: userVehiclesVM.vehicles[selected],
                    ns: ns,
                    onSpecs: { showSpecsPopup = true },
                    onMods: { showModsPopup = true }
                ) {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        selectedCarIndex = nil
                    }
                }
                .zIndex(1)
                .frame(maxWidth: 480)
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))

                if showSpecsPopup, userVehiclesVM.vehicles.indices.contains(selected) {
                    PopupCard {
                        SpecsListView(specs: userVehiclesVM.vehicles[selected].specs)
                    } onClose: { showSpecsPopup = false }
                    .zIndex(2)
                }

                if showModsPopup, userVehiclesVM.vehicles.indices.contains(selected) {
                    PopupCard {
                        ModsListView(mods: userVehiclesVM.vehicles[selected].mods)
                    } onClose: { showModsPopup = false }
                    .zIndex(2)
                }
            }

            // MARK: - Expanded community car overlay (legacy static cards)
            if selectedCommunityIndex != nil {
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            selectedCommunityIndex = nil
                        }
                    }
                    .zIndex(1)
            }

            CoolRipple(active: $ripple)
                .edgesIgnoringSafeArea(.all)

            // MARK: - Share success toast
            if showShareSuccessToast, let msg = shareSuccessToast {
                VStack {
                    TopToast(text: msg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                    Spacer()
                }
                .zIndex(10)
                .allowsHitTesting(false)
            }
        }
        // MARK: - Sheets & covers
        .fullScreenCover(isPresented: $showLightbox) {
            // lightbox is unused now that feed is real; kept for legacy wiring
            Color.black.ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showExploreFeed) {
            ExploreFeedView(communityCars: [], userCars: userVehiclesVM.vehicles, likedCommunity: $likedCommunity) {
                showExploreFeed = false
            }
            .environmentObject(authViewModel)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showVehicleEditor) {
            if let idx = editingIndex, userVehiclesVM.vehicles.indices.contains(idx) {
                VehicleEditorView(car: $userVehiclesVM.vehicles[idx]) { updated in
                    userVehiclesVM.updateVehicle(at: idx, with: updated)
                }
                .preferredColorScheme(.dark)
            } else if let first = userVehiclesVM.vehicles.indices.first {
                VehicleEditorView(car: $userVehiclesVM.vehicles[first]) { updated in
                    userVehiclesVM.updateVehicle(at: first, with: updated)
                }
                .preferredColorScheme(.dark)
                .onAppear { editingIndex = first }
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(Color("EmpireMint"))
                    Text("Creating a vehicle…")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
                .padding()
                .preferredColorScheme(.dark)
                .task {
                    if let newIdx = userVehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                        await MainActor.run { editingIndex = newIdx }
                    }
                }
            }
        }
        .sheet(isPresented: $showQuickMods) {
            if let first = userVehiclesVM.vehicles.indices.first {
                VehicleEditorView(car: $userVehiclesVM.vehicles[first]) { updated in
                    userVehiclesVM.updateVehicle(at: first, with: updated)
                }
                .preferredColorScheme(.dark)
            } else {
                quickEditorFallback(flag: $showQuickMods)
            }
        }
        .sheet(isPresented: $showQuickSpecs) {
            if let first = userVehiclesVM.vehicles.indices.first {
                VehicleEditorView(car: $userVehiclesVM.vehicles[first]) { updated in
                    userVehiclesVM.updateVehicle(at: first, with: updated)
                }
                .preferredColorScheme(.dark)
            } else {
                quickEditorFallback(flag: $showQuickSpecs)
            }
        }
        .sheet(isPresented: $showManageGarage) {
            ManageGarageSheet(vehiclesVM: userVehiclesVM)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showShareToFeed) {
            ShareToFeedSheet(userCars: userVehiclesVM.vehicles) { _ in
                shareSuccessToast = "Your build is live on the feed!"
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    showShareSuccessToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showShareSuccessToast = false
                    }
                }
            }
            .environmentObject(authViewModel)
            .preferredColorScheme(.dark)
        }
        // MARK: - Lifecycle
        .onAppear {
            userVehiclesVM.setContext(modelContext)
            Task {
                await authViewModel.refreshCarsFromBackendIfAuthenticated()
                await userVehiclesVM.loadVehicles()
                await communityVM.refresh()
            }
            userKey = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
            if let idx = editingIndex, !userVehiclesVM.vehicles.indices.contains(idx) { editingIndex = nil }
            if let sel = selectedCarIndex, !userVehiclesVM.vehicles.indices.contains(sel) { selectedCarIndex = nil }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await authViewModel.refreshCarsFromBackendIfAuthenticated()
                await userVehiclesVM.loadVehicles()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .empireCarsDidSync)) { _ in
            Task { await userVehiclesVM.loadVehicles() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .empireCommunityDidPost)) { _ in
            Task { await communityVM.refresh() }
        }
    }
}

// MARK: - Sections
private extension CarsView {

    var background: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear],
                           center: .top, startRadius: 20, endRadius: 300)
                .ignoresSafeArea()
        }
    }

    // MARK: User garage carousel

    var userCarousel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Text("My Garage")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showManageGarage = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Manage Garage")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(Color("EmpireMint"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(
                        Capsule().stroke(
                            LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            TabView(selection: $currentGarageIndex) {
                ForEach(userVehiclesVM.vehicles.indices, id: \.self) { idx in
                    VStack {
                        JiggleWrapper {
                            LiquidGlassCarCard(car: userVehiclesVM.vehicles[idx], ns: ns)
                                .frame(width: selectedCarIndex == idx ? 320 : 260,
                                       height: selectedCarIndex == idx ? 340 : 270)
                                .scaleEffect(currentGarageIndex == idx ? 1.05 : 0.95)
                        } onLongPress: {
                            editingIndex = idx
                            showVehicleEditor = true
                        } onTap: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                selectedCarIndex = selectedCarIndex == idx ? nil : idx
                                ripple = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { ripple = false }
                            if let sel = selectedCarIndex, !userVehiclesVM.vehicles.indices.contains(sel) {
                                selectedCarIndex = nil
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 340)

            HStack(spacing: 6) {
                ForEach(userVehiclesVM.vehicles.indices, id: \.self) { i in
                    Circle()
                        .fill(i == currentGarageIndex ? Color("EmpireMint").opacity(0.9) : Color.white.opacity(0.25))
                        .frame(width: i == currentGarageIndex ? 8 : 6, height: i == currentGarageIndex ? 8 : 6)
                        .animation(.easeInOut(duration: 0.2), value: currentGarageIndex)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Community section (real feed)

    var communitySection: some View {
        VStack(spacing: 12) {

            // Header row — title left, Explore Feed button right (fills remaining space)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Community Spotlight")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    if !communityVM.posts.isEmpty {
                        Text("\(communityVM.posts.count) post\(communityVM.posts.count == 1 ? "" : "s") from Empire drivers")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                        showExploreFeed = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Explore Feed")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color("EmpireMint"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [Color("EmpireMint").opacity(0.7), Color("EmpireMint").opacity(0.3)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.2
                            )
                            .blendMode(.screen)
                    )
                    .shadow(color: Color("EmpireMint").opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // Feed body
            if communityVM.isLoading && communityVM.posts.isEmpty {
                // Loading skeleton
                HStack(spacing: 10) {
                    ProgressView().tint(Color("EmpireMint"))
                    Text("Loading community posts…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

            } else if communityVM.posts.isEmpty {
                // Empty state
                VStack(spacing: 14) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color("EmpireMint").opacity(0.5))
                    Text("Be the first to share your build")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Post your car to the community feed and get discovered by other Empire drivers.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    if !userVehiclesVM.vehicles.isEmpty {
                        Button {
                            showShareToFeed = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Share your first build")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("EmpireMint"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color("EmpireMint").opacity(0.6), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 20)

            } else {
                // Horizontal preview strip — latest 6 posts
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(communityVM.posts.prefix(6))) { post in
                            CommunityPreviewTile(
                                post: post,
                                photoURL: communityVM.photoURL(for: post)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

        }
        .padding(.vertical, 8)
        .padding(.bottom, 60)
        .padding(.top, 4)
        .task { await communityVM.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .empireCommunityDidPost)) { _ in
            Task { await communityVM.refresh() }
        }
    }

    // MARK: Quick editor fallback

    @ViewBuilder
    func quickEditorFallback(flag: Binding<Bool>) -> some View {
        VStack(spacing: 12) {
            ProgressView().tint(Color("EmpireMint"))
            Text("Preparing editor…")
                .foregroundColor(.white)
                .font(.footnote)
        }
        .padding()
        .preferredColorScheme(.dark)
        .task {
            if let newIdx = userVehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                await MainActor.run {
                    editingIndex = newIdx
                    flag.wrappedValue = false
                    showVehicleEditor = true
                }
            }
        }
    }
}

// MARK: - Liquid Glass Car Card

private struct LiquidGlassCarCard: View {
    let car: Car
    var ns: Namespace.ID

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        .blendMode(.screen)
                )
                .shadow(color: Color("EmpireMint").opacity(0.14), radius: 14, x: 0, y: 8)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                .matchedGeometryEffect(id: "card-\(car.id)", in: ns)

            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Group {
                        if let data = loadPhotoDataFromDisk(fileName: car.photoFileName), let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage).resizable()
                        } else {
                            Image(car.imageName).resizable()
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .opacity(0.55)
                    .matchedGeometryEffect(id: "image-\(car.id)", in: ns)
                    .clipped()

                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.15), Color.black.opacity(0.45)],
                        startPoint: .top, endPoint: .bottom
                    )

                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.22), location: 0.48),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    .opacity(0.28)
                    .blur(radius: 10)
                    .rotationEffect(.degrees(18))
                    .modifier(CompactShineAnimation(cardCorner: 22))
                }
                .mask(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Spacer(minLength: 0)
                Text(car.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.white)
                    .matchedGeometryEffect(id: "title-\(car.id)", in: ns)
                HStack(spacing: 6) {
                    if car.isJailbreak {
                        StatCapsule(label: "Jailbreak", value: "", tint: .purple)
                    } else if car.stage == 0 {
                        StatCapsule(label: "Stock", value: "", tint: .gray)
                    } else {
                        StatCapsule(label: "Stage", value: "\(car.stage)", tint: stageTint(for: car.stage))
                    }
                    StatCapsule(label: "HP", value: "\(car.horsepower)", tint: .cyan)
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Community preview tile (horizontal strip)

struct CommunityPreviewTile: View {
    let post: CommunityPost
    let photoURL: URL?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Photo background
            ZStack {
                Color.white.opacity(0.06)

                if let url = photoURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 190)
                                .clipped()
                        case .empty:
                            ProgressView()
                                .tint(Color("EmpireMint"))
                                .scaleEffect(0.7)
                        default:
                            Image(systemName: "car.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color("EmpireMint").opacity(0.4))
                        }
                    }
                } else {
                    Image(systemName: "car.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color("EmpireMint").opacity(0.4))
                }
            }
            .frame(width: 150, height: 190)
            .overlay(
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
            )
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 4) {
                Text(post.username ?? "Driver")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Text(carDisplayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    tileStageChip
                    tileHPChip
                    if post.likesCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color("EmpireMint"))
                            Text("\(post.likesCount)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
            .padding(10)
        }
        .frame(width: 150, height: 190)
        .shadow(color: Color.black.opacity(0.5), radius: 10, y: 6)
    }

    private var carDisplayName: String {
        let parts = [post.make, post.model].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? post.carName : parts.joined(separator: " ")
    }

    @ViewBuilder
    private var tileStageChip: some View {
        let label: String = post.isJailbreak ? "Jailbreak" : (post.stage == 0 ? "Stock" : "Stage \(post.stage)")
        let tint: Color   = post.isJailbreak ? .purple : stageTint(for: post.stage)
        Text(label.uppercased())
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.15)))
            .overlay(Capsule().stroke(tint.opacity(0.65), lineWidth: 1))
    }

    private var tileHPChip: some View {
        Text("\(post.horsepower) HP")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(Color.cyan)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.cyan.opacity(0.15)))
            .overlay(Capsule().stroke(Color.cyan.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Jiggle wrapper

private struct JiggleWrapper<Content: View>: View {
    @State private var isJiggling: Bool = false
    @State private var isPressed: Bool = false
    let content: () -> Content
    let onLongPress: () -> Void
    let onTap: () -> Void

    var body: some View {
        content()
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .rotationEffect(.degrees(isJiggling ? 1.8 : 0), anchor: .center)
            .animation(isJiggling ? .easeInOut(duration: 0.09).repeatForever(autoreverses: true) : .default, value: isJiggling)
            .simultaneousGesture(TapGesture().onEnded { onTap() })
            .gesture(
                LongPressGesture(minimumDuration: 0.2)
                    .onChanged { _ in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.85)) { isPressed = true }
                        isJiggling = true
                    }
                    .onEnded { _ in
                        onLongPress()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) { isPressed = false }
                            isJiggling = false
                        }
                    }
            )
    }
}

// MARK: - Compact shine animation

private struct CompactShineAnimation: ViewModifier {
    @State private var phase: CGFloat = -1.1
    let cardCorner: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: phase * 220, y: phase * 80)
            .onAppear {
                phase = -1.1
                withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: false)) { phase = 1.3 }
            }
            .onDisappear { phase = -1.1 }
            .allowsHitTesting(false)
            .clipped()
    }
}

// MARK: - Stat capsule

private struct StatCapsule: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(tint.opacity(0.9))
            Text(value)
                .font(.caption2.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(tint.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Expanded card (inline, used inside the overlay)

private struct CarExpandedCardInline: View {
    let car: Car
    var ns: Namespace.ID
    var onSpecs: () -> Void = {}
    var onMods: () -> Void = {}
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilt: CGSize = .zero

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                        .blendMode(.screen)
                )
                .overlay(HoloShimmerMask().clipShape(RoundedRectangle(cornerRadius: 28)).opacity(reduceMotion ? 0 : 1))
                .shadow(color: Color("EmpireMint").opacity(0.18), radius: 22, x: 0, y: 14)
                .matchedGeometryEffect(id: "card-\(car.id)", in: ns)
                .rotation3DEffect(.degrees(Double(tilt.width) * 0.06), axis: (x: 0, y: 1, z: 0))
                .rotation3DEffect(.degrees(Double(-tilt.height) * 0.06), axis: (x: 1, y: 0, z: 0))

            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Group {
                        if let data = loadPhotoDataFromDisk(fileName: car.photoFileName), let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage).resizable()
                        } else {
                            Image(car.imageName).resizable()
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width + (reduceMotion ? 0 : tilt.width * 0.4), height: size.height)
                    .opacity(0.5)
                    .matchedGeometryEffect(id: "image-\(car.id)", in: ns)
                    .clipped()
                    .offset(x: reduceMotion ? 0 : tilt.width * 0.06, y: reduceMotion ? 0 : tilt.height * 0.04)

                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.12), Color.black.opacity(0.32)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .mask(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .allowsHitTesting(false)
            }

            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text(car.name)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)
                        .matchedGeometryEffect(id: "title-\(car.id)", in: ns)

                    if let make = car.make, !make.isEmpty, let model = car.model, !model.isEmpty {
                        Text("\(make) \(model)")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    } else {
                        Text(car.description)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)

                HStack(spacing: 10) {
                    if car.isJailbreak {
                        StatCapsule(label: "Jailbreak", value: "", tint: .purple)
                    } else if car.stage == 0 {
                        StatCapsule(label: "Stock", value: "", tint: .gray)
                    } else {
                        StatCapsule(label: "Stage", value: "\(car.stage)", tint: stageTint(for: car.stage))
                    }
                    StatCapsule(label: "HP", value: "\(car.horsepower)", tint: .cyan)
                }

                VStack(spacing: 10) {
                    StatRow(name: "Horsepower", value: Double(car.horsepower), max: 700, accent: Color("EmpireMint"))
                    StatRow(
                        name: car.isJailbreak ? "Jailbreak" : (car.stage == 0 ? "Stock" : "Stage"),
                        value: Double(car.isJailbreak ? 1 : car.stage),
                        max: car.isJailbreak ? 1 : 3,
                        accent: car.isJailbreak ? .purple : stageTint(for: car.stage)
                    )
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1
                                )
                        )
                )

                Spacer(minLength: 6)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        GlassButton(title: "Mods") { hapticTap(); onMods() }
                        GlassButton(title: "Specs") { hapticTap(); onSpecs() }
                        GlassButton(title: "Share") { hapticTap() }
                    }
                    GlassButton(title: "Close") { onClose() }
                        .padding(.top, 2)
                }
            }
            .padding(20)
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let w = max(-40, min(40, value.translation.width))
                    let h = max(-40, min(40, value.translation.height))
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { tilt = CGSize(width: w, height: h) }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { tilt = .zero }
                }
        )
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
    }
}

// MARK: - Stat row

private struct StatRow: View {
    let name: String
    let value: Double
    let max: Double
    let accent: Color
    @State private var animate: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(name).font(.caption2).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(displayValue).font(.caption2.weight(.semibold)).foregroundStyle(.white)
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [accent.opacity(0.9), accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: animate ? barWidth : 0)
                    .shadow(color: accent.opacity(0.4), radius: 6, x: 0, y: 2)
            }
            .frame(height: 8)
            .onAppear { withAnimation(.easeOut(duration: 0.6)) { animate = true } }
        }
    }

    private var normalized: Double {
        if name == "Stage" { return max == 0 ? 0 : Double(Swift.max(0, Swift.min(Int(value), 3))) / 3.0 }
        return max == 0 ? 0 : Swift.min(value / max, 1)
    }
    private var barWidth: CGFloat { CGFloat(normalized) * 220 }
    private var displayValue: String {
        if name == "Horsepower" { return "\(Int(value)) HP" }
        if name == "Jailbreak"  { return "Jailbreak" }
        if name == "Stock"      { return "Stock" }
        return String(format: "%.0f", value)
    }
}

// MARK: - Glass button

private struct GlassButton: View {
    let title: String
    var action: (() -> Void)? = nil
    var body: some View {
        Button(action: { action?() }) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(
                    Capsule().stroke(
                        LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color("EmpireMint").opacity(0.2), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Holo shimmer

private struct HoloShimmerMask: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white.opacity(0.3), location: 0.45),
                .init(color: .clear, location: 0.9)
            ]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .scaleEffect(x: 1.8)
        .offset(x: -120 + phase * 240)
        .onAppear { withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) { phase = 1 } }
        .blendMode(.screen)
        .opacity(0.6)
        .allowsHitTesting(false)
    }
}

// MARK: - Popup card

private struct PopupCard<Content: View>: View {
    @ViewBuilder var content: Content
    var onClose: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color("EmpireMint").opacity(0.12))
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.07)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Divider().background(Color.white.opacity(0.15))
                Button(action: onClose) {
                    Text("Close")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 360, maxHeight: 420)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color("EmpireMint").opacity(0.25), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }
}

// SpecsListView and ModsListView are defined in ExpandedCarView.swift — no redeclaration needed here.

// MARK: - Helpers

private func stageTint(for stage: Int) -> Color {
    switch stage {
    case 1: return Color("EmpireMint")
    case 2: return .yellow
    case 3: return .red
    default: return .gray
    }
}

private func hapticTap() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}

private func loadPhotoDataFromDisk(fileName: String?) -> Data? {
    guard let fileName else { return nil }
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return try? Data(contentsOf: dir.appendingPathComponent(fileName))
}

// MARK: - Preview

struct CarsView_Previews: PreviewProvider {
    static var previews: some View {
        CarsView()
            .preferredColorScheme(.dark)
    }
}
