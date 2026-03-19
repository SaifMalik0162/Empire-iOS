import SwiftUI
import UIKit
import SwiftData

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

    // MARK: - Community Cars
    @State private var communityCars: [Car] = [
        Car(name: "Honda Prelude BB2", description: "@officialtobysemple — Clean BB2 build", imageName: "prelude_bb2", horsepower: 450, stage: 3),
        Car(name: "Civic Si Coupe", description: "@fg2_corey — FG2 Si coupe", imageName: "civic_si_fg2", horsepower: 220, stage: 2),
        Car(name: "1968 Mustang", description: "347 Stroker V8", imageName: "68_blaze", horsepower: 350, stage: 2)
    ]

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
                        // quickActionsRow
                        Spacer(minLength: 24)
                    }
                    communitySection
                }
                .padding(.vertical, 6)
                .padding(.bottom, 40)
            }

            // Expanded card overlays above
            if let selected = selectedCarIndex, userVehiclesVM.vehicles.indices.contains(selected) {
                // Dim background
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
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
                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                    generator.impactOccurred()
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
                    } onClose: {
                        showSpecsPopup = false
                    }
                    .zIndex(2)
                }

                if showModsPopup, userVehiclesVM.vehicles.indices.contains(selected) {
                    PopupCard {
                        ModsListView(mods: userVehiclesVM.vehicles[selected].mods)
                    } onClose: {
                        showModsPopup = false
                    }
                    .zIndex(2)
                }
            }

            if let selected = selectedCommunityIndex, communityCars.indices.contains(selected) {
                // Dim background
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            selectedCommunityIndex = nil
                        }
                    }

                LiteCommunityExpandedCard(
                    car: communityCars[selected],
                    isLiked: likedCommunity.contains(communityCars[selected].id),
                    onLikeChanged: { liked in
                        let id = communityCars[selected].id
                        if liked { likedCommunity.insert(id) } else { likedCommunity.remove(id) }
                    }
                ) {
                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        selectedCommunityIndex = nil
                    }
                }
                .zIndex(1)
                .frame(maxWidth: 480)
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            }

            CoolRipple(active: $ripple)
                .edgesIgnoringSafeArea(.all)
        }
        .fullScreenCover(isPresented: $showLightbox) {
            CommunityLightbox(cars: communityCars, startIndex: lightboxIndex) {
                showLightbox = false
            }
        }
        .fullScreenCover(isPresented: $showExploreFeed) {
            ExploreFeedView(communityCars: communityCars, likedCommunity: $likedCommunity) {
                showExploreFeed = false
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showVehicleEditor) {
            if let idx = editingIndex, userVehiclesVM.vehicles.indices.contains(idx) {
                VehicleEditorView(car: $userVehiclesVM.vehicles[idx]) { updated in
                    userVehiclesVM.updateVehicle(at: idx, with: updated)
                }
                .preferredColorScheme(.dark)
            } else if let first = userVehiclesVM.vehicles.indices.first {
                // Fallback to first vehicle if the saved index became invalid
                VehicleEditorView(car: $userVehiclesVM.vehicles[first]) { updated in
                    userVehiclesVM.updateVehicle(at: first, with: updated)
                }
                .preferredColorScheme(.dark)
                .onAppear { editingIndex = first }
            } else {
                // No vehicles exist; create a placeholder and open editor
                VStack(spacing: 12) {
                    ProgressView().tint(Color("EmpireMint"))
                    Text("Creating a vehicle...")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
                .padding()
                .preferredColorScheme(.dark)
                .task {
                    if let newIdx = userVehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                        await MainActor.run {
                            editingIndex = newIdx
                        }
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
                VStack(spacing: 12) {
                    ProgressView().tint(Color("EmpireMint"))
                    Text("Preparing editor...")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
                .padding()
                .preferredColorScheme(.dark)
                .task {
                    if let newIdx = userVehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                        await MainActor.run {
                            editingIndex = newIdx
                            showVehicleEditor = true
                            showQuickMods = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showQuickSpecs) {
            if let first = userVehiclesVM.vehicles.indices.first {
                VehicleEditorView(car: $userVehiclesVM.vehicles[first]) { updated in
                    userVehiclesVM.updateVehicle(at: first, with: updated)
                }
                .preferredColorScheme(.dark)
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(Color("EmpireMint"))
                    Text("Preparing editor...")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
                .padding()
                .preferredColorScheme(.dark)
                .task {
                    if let newIdx = userVehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                        await MainActor.run {
                            editingIndex = newIdx
                            showVehicleEditor = true
                            showQuickSpecs = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showManageGarage) {
            ManageGarageSheet(vehiclesVM: userVehiclesVM)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            userVehiclesVM.setContext(modelContext)
            Task {
                await authViewModel.refreshCarsFromBackendIfAuthenticated()
                await userVehiclesVM.loadVehicles()
            }
            userKey = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
            if let idx = editingIndex, !userVehiclesVM.vehicles.indices.contains(idx) {
                editingIndex = nil
            }
            if let sel = selectedCarIndex, !userVehiclesVM.vehicles.indices.contains(sel) {
                selectedCarIndex = nil
            }
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
    }
}

// MARK: - Sections
private extension CarsView {
    var background: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                .ignoresSafeArea()
        }
    }

    var userCarousel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Text("My Garage")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
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
                    .background(
                        Capsule().fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Capsule().stroke(
                            LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                ripple = false
                            }
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
    
    var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                GlassActionButton(title: "Add Car", systemImage: "plus.circle.fill") {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    if let idx = userVehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                        editingIndex = idx
                        showVehicleEditor = true
                    }
                }
                GlassActionButton(title: "Log Mod", systemImage: "wrench.and.screwdriver.fill") {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    showQuickMods = true
                }
                GlassActionButton(title: "Add Spec", systemImage: "gauge.with.dots.needle.50percent") {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    showQuickSpecs = true
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    var communitySection: some View {
        VStack(spacing: 12) {
            // Header with inline Explore button - single line
            HStack(alignment: .center, spacing: 10) {
                Text("Community Spotlight")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)

                Spacer()

                // Wider glassy explore button
                Button(action: {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                        showExploreFeed = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("Explore Feed")
                            .font(.footnote.weight(.semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color("EmpireMint"))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [Color("EmpireMint").opacity(0.7), Color("EmpireMint").opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.2
                            ).blendMode(.screen)
                    )
                    .shadow(color: Color("EmpireMint").opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // Featured builds - horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(communityCars.indices, id: \.self) { idx in
                        ZStack(alignment: .bottomLeading) {
                            Image(communityCars[idx].imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 190)
                                .clipped()
                                .cornerRadius(16)
                                .overlay(
                                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                        .cornerRadius(16)
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                Text(communityCars[idx].name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .foregroundColor(.white)

                                HStack(spacing: 4) {
                                    if communityCars[idx].stage == 0 {
                                        StatCapsule(label: "Stock", value: "", tint: .gray)
                                    } else {
                                        StatCapsule(label: "Stage", value: "\(communityCars[idx].stage)", tint: stageTint(for: communityCars[idx].stage))
                                    }
                                    StatCapsule(label: "HP", value: "\(communityCars[idx].horsepower)", tint: .cyan)
                                }
                            }
                            .padding(8)
                        }
                        .frame(width: 150, height: 190)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 8)
        .padding(.bottom, 60)
        .padding(.top, 24)
    }
}

// MARK: - Liquid Glass Compact Card
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

            // Full-bleed background image
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Group {
                        if let data = loadPhotoDataFromDisk(fileName: car.photoFileName), let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                        } else {
                            Image(car.imageName)
                                .resizable()
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .opacity(0.55)
                    .matchedGeometryEffect(id: "image-\(car.id)", in: ns)
                    .clipped()

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.22), location: 0.48),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    .opacity(0.28)
                    .blur(radius: 10)
                    .rotationEffect(.degrees(18))
                    .modifier(CompactShineAnimation(cardCorner: 22))

                }
                .mask(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                )

            }

            // Foreground overlay
            VStack(alignment: .leading, spacing: 8) {
                Spacer(minLength: 0)

                Text(car.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.white)
                    .matchedGeometryEffect(id: "title-\(car.id)", in: ns)

                VStack(alignment: .leading, spacing: 6) {
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
            }
            .padding(14)
        }
    }
}

private func stageTint(for stage: Int) -> Color {
    switch stage {
    case 1: return Color("EmpireMint")
    case 2: return .yellow
    case 3: return .red
    default: return .gray
    }
}

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
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
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

private struct CompactShineAnimation: ViewModifier {
    @State private var phase: CGFloat = -1.1
    let cardCorner: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: phase * 220, y: phase * 80)
            .onAppear {
                phase = -1.1
                withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
            .onDisappear {
                // Reset so it restarts when the view reappears
                phase = -1.1
            }
            .allowsHitTesting(false)
            .clipped()
    }
}

private struct StatCapsule: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct TagChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            .foregroundStyle(.white)
    }
}

private struct GlassButton: View {
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color("EmpireMint").opacity(0.2), radius: 6, x: 0, y: 3)
    }
}

private struct GlassActionButton: View {
    let title: String
    let systemImage: String
    var action: (() -> Void)? = nil

    @State private var pressed: Bool = false

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color("EmpireMint"))
                    .shadow(color: Color("EmpireMint").opacity(0.35), radius: 8, x: 0, y: 4)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 92, height: 88)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color("EmpireMint").opacity(0.18), radius: 10, x: 0, y: 6)
            .scaleEffect(pressed ? 0.96 : 1.0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            pressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            pressed = false
                        }
                    }
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HoloShimmerMask: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white.opacity(0.3), location: 0.45),
                .init(color: .clear, location: 0.9)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .scaleEffect(x: 1.8)
        .offset(x: -120 + phase * 240)
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .blendMode(.screen)
        .opacity(0.6)
        .allowsHitTesting(false)
    }
}

private struct GalleryTile: View {
    let car: Car
    let isLiked: Bool
    let onToggleLike: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
         
            ZStack(alignment: .bottomLeading) {
                Image(car.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .allowsHitTesting(false)
                    )
                    .contentShape(Rectangle())

                // Metadata badges
                HStack(spacing: 8) {
                    if car.isJailbreak {
                        StatCapsule(label: "Jailbreak", value: "", tint: .purple)
                    } else if car.stage == 0 {
                        StatCapsule(label: "Stock", value: "", tint: .gray)
                    } else {
                        StatCapsule(label: "Stage", value: "\(car.stage)", tint: stageTint(for: car.stage))
                    }
                    StatCapsule(label: "HP", value: "\(car.horsepower)", tint: .cyan)
                }
                .padding(10)
            }

            // Like button
            Button(action: { onToggleLike() }) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? Color("EmpireMint") : .white)
                    .padding(8)
                    .background(
                        Circle().fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(10)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Expanded Card
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
            // Card base with glass and shimmer
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .blendMode(.screen)
                )
                .overlay(HoloShimmerMask().clipShape(RoundedRectangle(cornerRadius: 28)).opacity(reduceMotion ? 0 : 1))
                .shadow(color: Color("EmpireMint").opacity(0.18), radius: 22, x: 0, y: 14)
                .matchedGeometryEffect(id: "card-\(car.id)", in: ns)
                .rotation3DEffect(.degrees(Double(tilt.width) * 0.06), axis: (x: 0, y: 1, z: 0))
                .rotation3DEffect(.degrees(Double(-tilt.height) * 0.06), axis: (x: 1, y: 0, z: 0))

            // Embedded full-card image with parallax
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Group {
                        if let data = loadPhotoDataFromDisk(fileName: car.photoFileName), let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                        } else {
                            Image(car.imageName)
                                .resizable()
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width + (reduceMotion ? 0 : tilt.width * 0.4), height: size.height)
                    .opacity(0.5)
                    .matchedGeometryEffect(id: "image-\(car.id)", in: ns)
                    .accessibilityHidden(true)
                    .clipped()
                    .offset(x: reduceMotion ? 0 : tilt.width * 0.06, y: reduceMotion ? 0 : tilt.height * 0.04)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.12),
                            Color.black.opacity(0.32)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .mask(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .allowsHitTesting(false)
            }

            // Foreground content
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text(car.name)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)
                        .matchedGeometryEffect(id: "title-\(car.id)", in: ns)

                    // Show make and model if available, otherwise show description
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
                    StatRow(name: car.isJailbreak ? "Jailbreak" : (car.stage == 0 ? "Stock" : "Stage"), value: Double(car.isJailbreak ? 1 : car.stage), max: car.isJailbreak ? 1 : 3, accent: car.isJailbreak ? .purple : stageTint(for: car.stage))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
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

                    GlassButton(title: "Close") {
                        onClose()
                    }
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
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        tilt = CGSize(width: w, height: h)
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                        tilt = .zero
                    }
                }
        )
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
    }
}

// MARK: - Reusable Components
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

private struct StatRow: View {
    let name: String
    let value: Double
    let max: Double
    let accent: Color

    @State private var animate: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(displayValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [accent.opacity(0.9), accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: animate ? barWidth : 0)
                    .shadow(color: accent.opacity(0.4), radius: 6, x: 0, y: 2)
            }
            .frame(height: 8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    animate = true
                }
            }
        }
    }

    private var normalized: Double {
        if name == "Stage" {
            let clamped = Swift.max(0, Swift.min(Int(value), 3))
            return Double(clamped) / 3.0
        }
        return max == 0 ? 0 : Swift.min(value / max, 1)
    }
    private var barWidth: CGFloat { CGFloat(normalized) * 220 }
    private var displayValue: String {
        if name == "Stage" { return "\(Int(value))" }
        if name == "Horsepower" { return "\(Int(value)) HP" }
        return String(format: "%.0f", value)
    }
}

private func hapticTap() {
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
}

private struct CommunityLightbox: View {
    let cars: [Car]
    let startIndex: Int
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var liked: Set<UUID> = []
    @State private var showHeartBurst: Bool = false
    @State private var heartScale: CGFloat = 0.6
    @State private var heartOpacity: Double = 0.0

    init(cars: [Car], startIndex: Int, onClose: @escaping () -> Void) {
        self.cars = cars
        self.startIndex = startIndex
        self.onClose = onClose
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(cars.indices, id: \.self) { i in
                    GeometryReader { proxy in
                        let size = proxy.size
                        ZStack(alignment: .bottom) {
                            Image(cars[i].imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: size.width, maxHeight: size.height)
                                .tag(i)
                                .transition(.opacity)
                            // Double tap gesture
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    toggleLike()
                                    showHeartBurst = true
                                    heartScale = 0.6
                                    heartOpacity = 0.0
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                                        heartScale = 1.1
                                        heartOpacity = 1.0
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            heartScale = 0.9
                                            heartOpacity = 0.0
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            showHeartBurst = false
                                        }
                                    }
                                }

                            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                                .frame(height: 220)
                                .ignoresSafeArea(edges: .bottom)

                            // Bottom metadata overlay
                            VStack(alignment: .leading, spacing: 8) {
                                Text(cars[i].name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(cars[i].description)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(2)
                                HStack(spacing: 10) {
                                    if cars[i].isJailbreak {
                                        StatCapsule(label: "Jailbreak", value: "", tint: .purple)
                                    } else if cars[i].stage == 0 {
                                        StatCapsule(label: "Stock", value: "", tint: .gray)
                                    } else {
                                        StatCapsule(label: "Stage", value: "\(cars[i].stage)", tint: stageTint(for: cars[i].stage))
                                    }
                                    StatCapsule(label: "HP", value: "\(cars[i].horsepower)", tint: .cyan)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Heart burst overlay
            if showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(Color("EmpireMint"))
                    .shadow(color: Color("EmpireMint").opacity(0.6), radius: 12)
                    .scaleEffect(heartScale)
                    .opacity(heartOpacity)
                    .transition(.scale.combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .ignoresSafeArea()
                    .zIndex(3)
            }

            // Top controls
            VStack {
                HStack {
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        Button {
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                            toggleLike()
                        } label: {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? Color("EmpireMint") : .white)
                                .padding(10)
                                .background(Circle().fill(.ultraThinMaterial))
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        if let url = URL(string: "https://example.com/cars/\(cars[safe: index]?.id.uuidString ?? "")") {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            }
                        } else {
                            Button { } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                Spacer()
            }
        }
        .statusBarHidden(true)
    }

    private var isLiked: Bool {
        guard cars.indices.contains(index) else { return false }
        return liked.contains(cars[index].id)
    }

    private func toggleLike() {
        guard cars.indices.contains(index) else { return }
        let id = cars[index].id
        if liked.contains(id) { liked.remove(id) } else { liked.insert(id) }
    }

    private func shareCurrent() {
        // Placeholder share action
        // Integrate later
    }
}

// MARK: - Lite Community Expanded Card
private struct LiteCommunityExpandedCard: View {
    let car: Car
    var isLiked: Bool
    var onLikeChanged: (Bool) -> Void
    var onClose: () -> Void

    @State private var liked: Bool
    @State private var showHeartBurst: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilt: CGSize = .zero

    init(car: Car, isLiked: Bool, onLikeChanged: @escaping (Bool) -> Void, onClose: @escaping () -> Void) {
        self.car = car
        self.isLiked = isLiked
        self.onLikeChanged = onLikeChanged
        self.onClose = onClose
        _liked = State(initialValue: isLiked)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .blendMode(.screen)
                )
                .shadow(color: Color("EmpireMint").opacity(0.18), radius: 22, x: 0, y: 14)

            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Image(car.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width + (reduceMotion ? 0 : tilt.width * 0.4), height: size.height)
                        .opacity(0.5)
                        .accessibilityHidden(true)
                        .clipped()
                        .offset(x: reduceMotion ? 0 : tilt.width * 0.06, y: reduceMotion ? 0 : tilt.height * 0.04)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.12),
                            Color.black.opacity(0.32)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .mask(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .allowsHitTesting(false)
            }

            VStack(spacing: 14) {
                // Top bar with builder handle placeholder
                HStack {
                    Badge(text: "Community", color: Color("EmpireMint"))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                VStack(spacing: 6) {
                    Text(car.name)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)
                    Text(car.description)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 4)

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
                    StatRow(name: car.isJailbreak ? "Jailbreak" : (car.stage == 0 ? "Stock" : "Stage"), value: Double(car.isJailbreak ? 1 : car.stage), max: car.isJailbreak ? 1 : 3, accent: car.isJailbreak ? .purple : stageTint(for: car.stage))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )

                Spacer(minLength: 8)

                // Simplified community action row
                HStack(spacing: 12) {
                    GlassButton(title: "Follow") { hapticTap() }
                    GlassButton(title: "Save") { hapticTap() }
                    GlassButton(title: "Share") { hapticTap() }
                }

                GlassButton(title: "Close") {
                    onClose()
                }
                .padding(.top, 2)
            }
            .padding(20)

            // Heart burst overlay on like
            if showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(Color("EmpireMint"))
                    .shadow(color: Color("EmpireMint").opacity(0.6), radius: 12)
                    .transition(.scale.combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let w = Swift.max(-40, Swift.min(40, value.translation.width))
                    let h = Swift.max(-40, Swift.min(40, value.translation.height))
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        tilt = CGSize(width: w, height: h)
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                        tilt = .zero
                    }
                }
        )
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                    liked.toggle()
                }
                onLikeChanged(liked)
                showHeartBurst = true
                var workItem: DispatchWorkItem?
                workItem = DispatchWorkItem {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showHeartBurst = false
                    }
                }
                // Hide after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: workItem!)
            }
        )
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
    }
}

// MARK: - Preview
struct CarsView_Previews: PreviewProvider {
    static var previews: some View {
        CarsView()
            .preferredColorScheme(.dark)
    }
}

// MARK: - Small image loader from disk for given photoFileName
private func loadPhotoDataFromDisk(fileName: String?) -> Data? {
    guard let fileName else { return nil }
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let url = dir.appendingPathComponent(fileName)
    return try? Data(contentsOf: url)
}

// MARK: - Local PopupCard, SpecsListView, ModsListView for use in CarsView

private struct PopupCard<Content: View>: View {
    @ViewBuilder var content: Content
    var onClose: () -> Void
    var body: some View {
        ZStack {
            // Dim background and allow tap-to-dismiss
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Centered compact card
            VStack(spacing: 0) {
                // Content area (do NOT wrap a List in ScrollView)
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
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.07)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Divider and embedded Close button
                Divider().background(Color.white.opacity(0.15))
                Button(action: onClose) {
                    Text("Close")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 360, maxHeight: 420)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color("EmpireMint").opacity(0.25), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }
}

private struct SpecsListView: View {
    let specs: [SpecItem]
    var body: some View {
        NavigationStack {
            List {
                if specs.isEmpty {
                    Section { Text("No specs added yet").foregroundColor(.secondary) }
                } else {
                    ForEach(specs) { item in
                        HStack {
                            Text(item.key).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            Spacer()
                            Text(item.value).font(.subheadline).foregroundColor(.white.opacity(0.85))
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12).stroke(
                                        LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 1
                                    )
                                )
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            )
            .navigationTitle("Specs")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct ModsListView: View {
    let mods: [ModItem]
    var body: some View {
        NavigationStack {
            List {
                if mods.isEmpty {
                    Section { Text("No mods added yet").foregroundColor(.secondary) }
                } else {
                    ForEach(mods) { mod in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mod.title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            if !mod.notes.isEmpty {
                                Text(mod.notes).font(.footnote).foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12).stroke(
                                        LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 1
                                    )
                                )
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            )
            .navigationTitle("Mods")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Explore Gallery Sheet
private struct ExploreGallerySheet: View {
    let communityCars: [Car]
    @Binding var likedCommunity: Set<UUID>
    @Environment(\.dismiss) private var dismiss
    @State private var showContent: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            RadialGradient(colors: [Color("EmpireMint").opacity(0.12), .clear], center: .topLeading, startRadius: 20, endRadius: 300)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Enhanced Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("All Builds")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                            Text("Explore the community's finest creations")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color("EmpireMint").opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(.ultraThinMaterial)
                )

                Divider()
                    .opacity(0.2)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14)
                        ], spacing: 14) {
                            ForEach(communityCars.indices, id: \.self) { idx in
                                GalleryTile(
                                    car: communityCars[idx],
                                    isLiked: likedCommunity.contains(communityCars[idx].id),
                                    onToggleLike: {
                                        let id = communityCars[idx].id
                                        if likedCommunity.contains(id) {
                                            likedCommunity.remove(id)
                                        } else {
                                            likedCommunity.insert(id)
                                        }
                                    }
                                )
                                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.9)), removal: .opacity))
                            }
                        }
                        .padding(.horizontal, 20)

                        // Empty space at bottom for scrolling
                        Color.clear
                            .frame(height: 20)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showContent = true
            }
        }
    }
}

