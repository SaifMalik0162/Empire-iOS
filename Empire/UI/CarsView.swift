import SwiftUI
import UIKit
import SwiftData
import Combine

struct CarsView: View {
    // MARK: - User's cars
    @StateObject private var userVehiclesVM = UserVehiclesViewModel()
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appNavigation: AppNavigationModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAddVehicle: Bool = false
    @State private var editingCarID: UUID? = nil
    @State private var showVehicleEditor: Bool = false
    @State private var userKey: String = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
    @State private var showQuickMods: Bool = false
    @State private var showQuickSpecs: Bool = false
    @State private var currentGarageIndex: Int = 0
    @State private var centeredGarageCarID: UUID? = nil
    @State private var showManageGarage: Bool = false
    @GestureState private var garageDragOffset: CGFloat = 0

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
    @State private var exploreInitialPostID: UUID? = nil
    @State private var exploreInitialProfileUserID: String? = nil

    var body: some View {
        ZStack {
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {

                    if userVehiclesVM.vehicles.isEmpty {
                        emptyGarageState
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
                    isSource: true,
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
            Color.black.ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showExploreFeed) {
            ExploreFeedView(
                communityCars: [],
                userCars: userVehiclesVM.vehicles,
                initialPostID: exploreInitialPostID,
                initialProfileUserID: exploreInitialProfileUserID,
                likedCommunity: $likedCommunity
            ) {
                showExploreFeed = false
            }
            .environmentObject(authViewModel)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showVehicleEditor) {
            if let idx = editingVehicleIndex {
                VehicleEditorView(car: $userVehiclesVM.vehicles[idx]) { updated in
                    userVehiclesVM.updateVehicle(at: idx, with: updated)
                }
                .preferredColorScheme(.dark)
            } else if let first = userVehiclesVM.vehicles.indices.first {
                VehicleEditorView(car: $userVehiclesVM.vehicles[first]) { updated in
                    userVehiclesVM.updateVehicle(at: first, with: updated)
                }
                .preferredColorScheme(.dark)
                .onAppear { editingCarID = userVehiclesVM.vehicles[first].id }
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
                        await MainActor.run { editingCarID = userVehiclesVM.vehicles[safe: newIdx]?.id }
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
            ShareToFeedSheet(
                userCars: userVehiclesVM.vehicles,
                preselectedIndex: currentGarageIndex,
                onPosted: { _ in
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
            )
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
            if let editingCarID,
               userVehiclesVM.vehicles.contains(where: { $0.id == editingCarID }) == false {
                self.editingCarID = nil
            }
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
        .onAppear {
            handlePendingDeepLink()
        }
        .onChange(of: appNavigation.pendingDeepLink) { _, _ in
            handlePendingDeepLink()
        }
    }
}

// MARK: - Sections
private extension CarsView {

    func beginAddingFirstVehicle() {
        if let idx = userVehiclesVM.addPlaceholderVehicleAndReturnIndex() {
            editingCarID = userVehiclesVM.vehicles[safe: idx]?.id
            showVehicleEditor = true
        }
    }

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

    var emptyGarageState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text("My Garage")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)

            GeometryReader { proxy in
                let cardWidth: CGFloat = min(252, max(224, proxy.size.width - 132))
                let cardHeight: CGFloat = 286

                Button(action: beginAddingFirstVehicle) {
                    EmptyGarageCard()
                        .frame(width: cardWidth, height: cardHeight)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 314)
            .clipped()

            Circle()
                .fill(Color("EmpireMint").opacity(0.9))
                .frame(width: 8, height: 8)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity)
        }
    }

    var userCarousel: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header row
            HStack(alignment: .center, spacing: 8) {
                Text("My Garage")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Spacer()

                // Share Build
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showShareToFeed = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Share Build")
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(Color("EmpireMint"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(
                        Capsule().stroke(
                            LinearGradient(
                                colors: [Color("EmpireMint").opacity(0.6), Color("EmpireMint").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
                .fixedSize()

                // Manage Garage
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showManageGarage = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Manage Garage")
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(Color("EmpireMint"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(
                        Capsule().stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)

            GeometryReader { proxy in
                let cardWidth: CGFloat = min(252, max(224, proxy.size.width - 132))
                let cardHeight: CGFloat = 286
                let spacing: CGFloat = 18
                let stride = cardWidth + spacing
                let baseOffset = (proxy.size.width - cardWidth) / 2
                let canSwipeGarage = userVehiclesVM.vehicles.count > 1

                HStack(spacing: spacing) {
                    ForEach(userVehiclesVM.vehicles.indices, id: \.self) { idx in
                        let car = userVehiclesVM.vehicles[idx]
                        let isActive = idx == currentGarageIndex

                        JiggleWrapper {
                            LiquidGlassCarCard(
                                car: car,
                                ns: ns,
                                isSource: selectedCarIndex != idx,
                                isCentered: isActive
                            )
                            .frame(width: cardWidth, height: cardHeight)
                            .scaleEffect(isActive ? 1.0 : 0.94)
                            .opacity(isActive ? 1.0 : 0.82)
                            .rotation3DEffect(.degrees(isActive ? 0 : (idx < currentGarageIndex ? 8 : -8)), axis: (x: 0, y: 1, z: 0), perspective: 0.82)
                            .offset(y: isActive ? 0 : 6)
                        } onLongPress: {
                            editingCarID = car.id
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
                    }
                }
                .offset(x: baseOffset - (CGFloat(currentGarageIndex) * stride) + garageDragOffset, y: 0)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .updating($garageDragOffset) { value, state, _ in
                            guard canSwipeGarage else {
                                state = 0
                                return
                            }
                            state = value.translation.width
                        }
                        .onEnded { value in
                            guard canSwipeGarage else { return }
                            let threshold = stride * 0.22
                            var newIndex = currentGarageIndex

                            if value.translation.width <= -threshold {
                                newIndex = min(currentGarageIndex + 1, userVehiclesVM.vehicles.count - 1)
                            } else if value.translation.width >= threshold {
                                newIndex = max(currentGarageIndex - 1, 0)
                            }

                            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                                currentGarageIndex = newIndex
                                centeredGarageCarID = userVehiclesVM.vehicles[safe: newIndex]?.id
                            }
                        }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: 314)
            .clipped()
            .onAppear {
                if let centeredGarageCarID,
                   let idx = userVehiclesVM.vehicles.firstIndex(where: { $0.id == centeredGarageCarID }) {
                    currentGarageIndex = idx
                } else {
                    currentGarageIndex = 0
                    centeredGarageCarID = userVehiclesVM.vehicles.first?.id
                }
            }
            .onChange(of: userVehiclesVM.vehicles.map(\.id)) { _, ids in
                guard !ids.isEmpty else {
                    centeredGarageCarID = nil
                    currentGarageIndex = 0
                    return
                }
                if let centeredGarageCarID,
                   let matchedIndex = ids.firstIndex(of: centeredGarageCarID) {
                    currentGarageIndex = matchedIndex
                } else {
                    currentGarageIndex = 0
                    centeredGarageCarID = ids.first
                }
            }

            HStack(spacing: 6) {
                ForEach(userVehiclesVM.vehicles.indices, id: \.self) { i in
                    Circle()
                        .fill(i == currentGarageIndex ? Color("EmpireMint").opacity(0.9) : Color.white.opacity(0.25))
                        .frame(width: i == currentGarageIndex ? 8 : 6, height: i == currentGarageIndex ? 8 : 6)
                        .animation(.easeInOut(duration: 0.2), value: currentGarageIndex)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Community section

    var communitySection: some View {
        VStack(spacing: 14) {

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Community Spotlight")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    if communityVM.totalPostsCount > 0 {
                        Text("\(communityVM.totalPostsCount) post\(communityVM.totalPostsCount == 1 ? "" : "s") from Empire drivers")
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
            .padding(.top, 0)

            if communityVM.isLoading && communityVM.posts.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().tint(Color("EmpireMint"))
                    Text("Loading community posts…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

            } else if communityVM.posts.isEmpty {
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
                        Button { showShareToFeed = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Share your first build")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("EmpireMint"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color("EmpireMint").opacity(0.6), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)

            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(communityVM.posts.prefix(3))) { post in
                            CommunityPreviewTile(
                                post: post,
                                photoURL: communityVM.photoURL(for: post, variant: .grid)
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
                    editingCarID = userVehiclesVM.vehicles[safe: newIdx]?.id
                    flag.wrappedValue = false
                    showVehicleEditor = true
                }
            }
        }
    }
}

private extension CarsView {
    func handlePendingDeepLink() {
        guard let deepLink = appNavigation.pendingDeepLink else { return }
        switch deepLink {
        case .post(let postId):
            exploreInitialPostID = postId
            exploreInitialProfileUserID = nil
            showExploreFeed = true
            appNavigation.consume(deepLink)
        case .profile(let userId):
            exploreInitialProfileUserID = userId
            exploreInitialPostID = nil
            showExploreFeed = true
            appNavigation.consume(deepLink)
        case .meet:
            break
        }
    }

    var editingVehicleIndex: Int? {
        guard let editingCarID else { return nil }
        return userVehiclesVM.vehicles.firstIndex(where: { $0.id == editingCarID })
    }
}

// MARK: - Liquid Glass Car Card

private struct LiquidGlassCarCard: View {
    let car: Car
    var ns: Namespace.ID
    var isSource: Bool = true
    var isCentered: Bool = false

    private var hasMetadataBadges: Bool {
        car.buildCategory != nil || car.vehicleClass != nil
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(isCentered ? 0.12 : 0.08), Color.white.opacity(isCentered ? 0.035 : 0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(isCentered ? 0.18 : 0.14))
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RadialGradient(
                        colors: [Color("EmpireMint").opacity(isCentered ? 0.24 : 0.1), .clear],
                        center: .bottomLeading,
                        startRadius: 12,
                        endRadius: 180
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [Color("EmpireMint").opacity(isCentered ? 0.55 : 0.18), Color.white.opacity(isCentered ? 0.14 : 0.06)],
                                startPoint: .bottomLeading,
                                endPoint: .topTrailing
                            ),
                            lineWidth: isCentered ? 1.3 : 1
                        )
                        .blendMode(.screen)
                )
                .shadow(color: Color("EmpireMint").opacity(isCentered ? 0.24 : 0.12), radius: isCentered ? 20 : 12, x: 0, y: isCentered ? 12 : 8)
                .shadow(color: .black.opacity(isCentered ? 0.42 : 0.35), radius: isCentered ? 18 : 10, x: 0, y: isCentered ? 12 : 6)
                .matchedGeometryEffect(id: "card-\(car.id)", in: ns, isSource: isSource)

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
                    .opacity(isCentered ? 0.68 : 0.58)
                    .matchedGeometryEffect(id: "image-\(car.id)", in: ns, isSource: isSource)
                    .clipped()

                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(isCentered ? 0.1 : 0.15), Color.black.opacity(isCentered ? 0.34 : 0.45)],
                        startPoint: .top, endPoint: .bottom
                    )

                    LinearGradient(
                        colors: [Color.white.opacity(isCentered ? 0.08 : 0.02), .clear, Color.black.opacity(isCentered ? 0.18 : 0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(isCentered ? 0.18 : 0.1), location: 0.48),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    .opacity(isCentered ? 0.22 : 0.1)
                    .blur(radius: 14)
                    .rotationEffect(.degrees(18))
                    .modifier(CompactShineAnimation(isActive: isCentered))
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
                    .matchedGeometryEffect(id: "title-\(car.id)", in: ns, isSource: isSource)

                if hasMetadataBadges {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            metadataBadges
                            stageAndPowerBadges
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            metadataBadges
                            stageAndPowerBadges
                        }
                    }
                } else {
                    stageAndPowerBadges
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .compositingGroup()
    }

    @ViewBuilder
    private var metadataBadges: some View {
        HStack(spacing: 6) {
            if let buildCategory = car.buildCategory {
                BuildCategoryBadge(category: buildCategory, size: 20, materialOpacity: 0.14, strokeOpacity: 0.5)
            }
            if let vehicleClass = car.vehicleClass {
                VehicleClassBadge(vehicleClass: vehicleClass, size: 20, materialOpacity: 0.14, strokeOpacity: 0.5)
            }
        }
    }

    private var stageAndPowerBadges: some View {
        HStack(spacing: 6) {
            StatCapsule(
                label: StageSystem.displayLabel(for: car.stage, isJailbreak: car.isJailbreak),
                value: "",
                tint: StageSystem.accentColor(for: car.stage, isJailbreak: car.isJailbreak)
            )
            StatCapsule(label: "WHP", value: "\(car.horsepower)", tint: .cyan)
        }
    }
}

private struct EmptyGarageCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("FIRST BUILD")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(Color("EmpireMint").opacity(0.82))

                Spacer()
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color("EmpireMint"))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color("EmpireMint").opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color("EmpireMint").opacity(0.22), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add your first build")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Create a vehicle card to start your garage.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 8) {
                    Text("Start your garage")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("EmpireMint"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color("EmpireMint").opacity(0.46), Color.white.opacity(0.08)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.14))
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RadialGradient(
                        colors: [Color("EmpireMint").opacity(0.14), .clear],
                        center: .bottomLeading,
                        startRadius: 16,
                        endRadius: 190
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color("EmpireMint").opacity(0.34), Color.white.opacity(0.08)],
                                startPoint: .bottomLeading,
                                endPoint: .topTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color("EmpireMint").opacity(0.16), radius: 16, x: 0, y: 10)
        .shadow(color: .black.opacity(0.34), radius: 16, x: 0, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Community preview tile

struct CommunityPreviewTile: View {
    let post: CommunityPost
    let photoURL: URL?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                Color.white.opacity(0.06)
                if let url = photoURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                                .frame(width: 150, height: 190).clipped()
                        case .empty:
                            ProgressView().tint(Color("EmpireMint")).scaleEffect(0.7)
                        default:
                            Image(systemName: "car.fill").font(.system(size: 22))
                                .foregroundStyle(Color("EmpireMint").opacity(0.4))
                        }
                    }
                } else {
                    Image(systemName: "car.fill").font(.system(size: 22))
                        .foregroundStyle(Color("EmpireMint").opacity(0.4))
                }
            }
            .frame(width: 150, height: 190)
            .overlay(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom))
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 4) {
                Text(post.username ?? "Driver")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Text(post.carName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let makeModelLine, !makeModelLine.isEmpty, makeModelLine != post.carName {
                    Text(makeModelLine)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    tileStageChip
                    tileHPChip
                    if post.likesCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill").font(.system(size: 8)).foregroundStyle(Color("EmpireMint"))
                            Text("\(post.likesCount)").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
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

    private var makeModelLine: String? {
        let parts: [String] = [post.make, post.model].compactMap { value in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    @ViewBuilder
    private var tileStageChip: some View {
        let label = StageSystem.displayLabel(for: post.stage, isJailbreak: post.isJailbreak)
        let tint = StageSystem.accentColor(for: post.stage, isJailbreak: post.isJailbreak)
        Text(label.uppercased())
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(tint)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.15)))
            .overlay(Capsule().stroke(tint.opacity(0.65), lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tileHPChip: some View {
        Text("\(post.horsepower) WHP")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(Color.cyan)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(Color.cyan.opacity(0.15)))
            .overlay(Capsule().stroke(Color.cyan.opacity(0.6), lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
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
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: phase * 180, y: phase * 58)
            .onAppear {
                phase = -1.1
                guard isActive else { return }
                withAnimation(.linear(duration: 9.5).repeatForever(autoreverses: false)) {
                    phase = 1.15
                }
            }
            .onDisappear { phase = -1.1 }
            .onChange(of: isActive) { _, newValue in
                phase = -1.1
                guard newValue else { return }
                withAnimation(.linear(duration: 9.5).repeatForever(autoreverses: false)) {
                    phase = 1.15
                }
            }
            .allowsHitTesting(false)
            .clipped()
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
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .onDisappear { phase = 0 }
        .blendMode(.screen)
        .opacity(0.6)
        .allowsHitTesting(false)
    }
}

// MARK: - Stat capsule

private struct StatCapsule: View {
    let label: String
    let value: String
    let tint: Color

    private var hasValue: Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        Group {
            if hasValue {
                HStack(spacing: 6) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(tint.opacity(0.9))
                    Text(value)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.white)
                }
            } else {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(tint.opacity(0.9))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(tint.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Expanded card inline

private struct CarExpandedCardInline: View {
    let car: Car
    var ns: Namespace.ID
    var isSource: Bool = true
    var onSpecs: () -> Void = {}
    var onMods: () -> Void = {}
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilt: CGSize = .zero

    private var hasMetadataBadges: Bool {
        car.buildCategory != nil || car.vehicleClass != nil
    }

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
                .matchedGeometryEffect(id: "card-\(car.id)", in: ns, isSource: isSource)
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
                    .matchedGeometryEffect(id: "image-\(car.id)", in: ns, isSource: isSource)
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
                        .matchedGeometryEffect(id: "title-\(car.id)", in: ns, isSource: isSource)

                    if let make = car.make, !make.isEmpty, let model = car.model, !model.isEmpty {
                        Text("\(make) \(model)")
                            .font(.footnote).foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center).padding(.horizontal, 16)
                    } else {
                        Text(car.description)
                            .font(.footnote).foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center).padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)

                if hasMetadataBadges {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            metadataBadges
                            stageAndPowerBadges
                        }

                        VStack(spacing: 8) {
                            metadataBadges
                            stageAndPowerBadges
                        }
                    }
                } else {
                    stageAndPowerBadges
                }

                VStack(spacing: 10) {
                    StatRow(name: "Horsepower", value: Double(car.horsepower), max: 700, accent: Color("EmpireMint"))
                    StatRow(
                        name: StageSystem.displayLabel(for: car.stage, isJailbreak: car.isJailbreak),
                        value: Double(car.isJailbreak ? 1 : car.stage),
                        max: car.isJailbreak ? 1 : 6,
                        accent: StageSystem.accentColor(for: car.stage, isJailbreak: car.isJailbreak)
                    )
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                )

                Spacer(minLength: 6)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        GlassButton(title: "Mods") { hapticTap(); onMods() }
                        GlassButton(title: "Specs") { hapticTap(); onSpecs() }
                        GlassButton(title: "Share") { hapticTap() }
                    }
                    GlassButton(title: "Close") { onClose() }.padding(.top, 2)
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

    @ViewBuilder
    private var metadataBadges: some View {
        HStack(spacing: 8) {
            if let buildCategory = car.buildCategory {
                BuildCategoryBadge(category: buildCategory, size: 22, materialOpacity: 0.14, strokeOpacity: 0.55)
            }
            if let vehicleClass = car.vehicleClass {
                VehicleClassBadge(vehicleClass: vehicleClass, size: 22, materialOpacity: 0.14, strokeOpacity: 0.55)
            }
        }
    }

    private var stageAndPowerBadges: some View {
        HStack(spacing: 10) {
            StatCapsule(
                label: StageSystem.displayLabel(for: car.stage, isJailbreak: car.isJailbreak),
                value: "",
                tint: StageSystem.accentColor(for: car.stage, isJailbreak: car.isJailbreak)
            )
            StatCapsule(label: "WHP", value: "\(car.horsepower)", tint: .cyan)
        }
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
        if name.hasPrefix("Stage") || name == "MAX" {
            return max == 0 ? 0 : Double(Swift.max(0, Swift.min(Int(value), Int(max)))) / max
        }
        return max == 0 ? 0 : Swift.min(value / max, 1)
    }
    private var barWidth: CGFloat { CGFloat(normalized) * 220 }
    private var displayValue: String {
        if name == "Horsepower" { return "\(Int(value)) WHP" }
        if name == "Jailbreak"  { return "Jailbreak" }
        if name == "Stock"      { return "Stock" }
        if name == "MAX"        { return "MAX" }
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
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color("EmpireMint").opacity(0.2), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Popup card

private struct PopupCard<Content: View>: View {
    @ViewBuilder var content: Content
    var onClose: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { onClose() }
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color("EmpireMint").opacity(0.12))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.07)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Divider().background(Color.white.opacity(0.15))
                Button(action: onClose) {
                    Text("Close").font(.caption.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .foregroundStyle(.white).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 360, maxHeight: 420)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color("EmpireMint").opacity(0.25), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }
}

// MARK: - Helpers

private func stageTint(for stage: Int) -> Color {
    StageSystem.accentColor(for: stage, isJailbreak: false)
}

private func hapticTap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

private func loadPhotoDataFromDisk(fileName: String?) -> Data? {
    guard let fileName else { return nil }
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return try? Data(contentsOf: dir.appendingPathComponent(fileName))
}

// MARK: - Preview

struct CarsView_Previews: PreviewProvider {
    static var previews: some View {
        CarsView().preferredColorScheme(.dark)
    }
}
