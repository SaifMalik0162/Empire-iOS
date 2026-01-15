import SwiftUI
import UIKit

struct CarsView: View {
    // MARK: - User's cars
    @StateObject private var userVehiclesVM = UserVehiclesViewModel()
    @State private var showAddVehicle:  Bool = false
    @State private var editingIndex: Int?  = nil
    @State private var showVehicleEditor:  Bool = false
    @State private var userKey: String = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
    
    // MARK: - Community Cars
    @State private var communityCars: [Car] = [
        Car(name: "Honda Prelude BB2", description: "@officialtobysemple — Clean BB2 build", imageName: "prelude_bb2", horsepower: 450, stage: 3),
        Car(name: "Civic Si Coupe", description: "@fg2_corey — FG2 Si coupe", imageName: "civic_si_fg2", horsepower: 220, stage: 2),
        Car(name: "1968 Mustang", description: "347 Stroker V8", imageName: "68_blaze", horsepower: 350, stage: 2)
    ]

    @State private var selectedCarIndex: Int?  = nil
    @Namespace private var ns
    @State private var ripple: Bool = false
    @State private var showLightbox: Bool = false
    @State private var lightboxIndex: Int = 0
    
    @State private var selectedCommunityIndex: Int? = nil
    @State private var likedCommunity: Set<UUID> = []

    var body: some View {
        ZStack {
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    if userVehiclesVM.vehicles.isEmpty {
                        Button {
                            Task {  // ← WRAP IN TASK
                                if let idx = await userVehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                                    editingIndex = idx
                                    showVehicleEditor = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus. circle.fill")
                                Text("Add your first vehicle")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color("EmpireMint"))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06))
                            )
                        }
                        . buttonStyle(. plain)
                        .padding(.horizontal, 20)
                    } else {
                        userCarousel
                    }
                    communitySection
                }
                .padding(.vertical, 12)
            }
            .refreshable {
                await userVehiclesVM.loadVehicles()
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

                CarExpandedCardInline(car: userVehiclesVM.vehicles[selected], ns: ns) {
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
                        withAnimation(. spring(response: 0.45, dampingFraction: 0.82)) {
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
                .padding(. vertical, 30)
                .transition(.asymmetric(insertion: .opacity.combined(with: . scale(scale: 0.98)), removal: .opacity))
            }

            CoolRipple(active: $ripple)
                .edgesIgnoringSafeArea(. all)
        }
        .fullScreenCover(isPresented:  $showLightbox) {
            CommunityLightbox(cars: communityCars, startIndex: lightboxIndex) {
                showLightbox = false
            }
        }
        .sheet(isPresented: $showVehicleEditor) {
            if let idx = editingIndex, userVehiclesVM.vehicles.indices.contains(idx) {
                VehicleEditorView(car: $userVehiclesVM.vehicles[idx]) { updated, imageData in
                    Task {
                        await userVehiclesVM.updateVehicle(at: idx, with: updated, imageData: imageData)
                    }
                }
                .preferredColorScheme(.dark)
            } else if let first = userVehiclesVM.vehicles.indices.first {
                // Fallback to first vehicle if the saved index became invalid
                VehicleEditorView(car: $userVehiclesVM.vehicles[first]) { updated, imageData in
                    Task {
                        await userVehiclesVM.updateVehicle(at: first, with: updated, imageData: imageData)
                    }
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
                . padding()
                .preferredColorScheme(.dark)
                .task {
                    if let newIdx = await userVehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                        await MainActor.run {
                            editingIndex = newIdx
                        }
                    }
                }
            }
        }
        .onAppear {
            Task { await userVehiclesVM.loadVehicles() }
            userKey = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
            if let idx = editingIndex, !userVehiclesVM.vehicles.indices.contains(idx) {
                editingIndex = nil
            }
            if let sel = selectedCarIndex, !userVehiclesVM.vehicles.indices.contains(sel) {
                selectedCarIndex = nil
            }
        }
    }
}

// MARK:  - Sections
private extension CarsView {
    var background: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)],
                           startPoint: .top,
                           endPoint: . bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                .ignoresSafeArea()
        }
    }

    var userCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(userVehiclesVM.vehicles.indices, id: \.self) { idx in
                    JiggleWrapper {
                        LiquidGlassCarCard(car: userVehiclesVM.vehicles[idx], ns: ns)
                            .frame(width: selectedCarIndex == idx ? 300 : 220,
                                   height: selectedCarIndex == idx ? 380 : 250)
                            .scaleEffect(selectedCarIndex == idx ? 1.04 : 1)
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
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 360)
    }

    var communitySection:  some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Community Gallery")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(. white)
                Spacer()
                Text("See All")
                    .font(.caption)
                    .foregroundColor(Color("EmpireMint").opacity(0.9))
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 12)
            ], spacing: 12) {
                ForEach(communityCars.indices, id: \.self) { idx in
                    GalleryTile(
                        car: communityCars[idx],
                        isLiked: likedCommunity.contains(communityCars[idx].id),
                        onToggleLike: {
                            let id = communityCars[idx].id
                            if likedCommunity.contains(id) { likedCommunity.remove(id) } else { likedCommunity.insert(id) }
                        }
                    )
                    .onTapGesture {
                        selectedCommunityIndex = idx
                    }
                    .onLongPressGesture(minimumDuration: 0.35) {
                        lightboxIndex = idx
                        showLightbox = true
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK:  - Liquid Glass Compact Card
private struct LiquidGlassCarCard: View {
    let car: Car
    var ns: Namespace.ID

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(. ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        .blendMode(.screen)
                )
                .shadow(color: Color("EmpireMint").opacity(0.18), radius: 18, x: 0, y:  10)
                .shadow(color: . black.opacity(0.5), radius: 12, x: 0, y:  6)
                .matchedGeometryEffect(id:  "card-\(car.id)", in: ns)

            // Full-bleed background image
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Group {
                        if let data = loadSavedPhotoData(for: car.id), let uiImage = UIImage(data: data) {
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
                    .matchedGeometryEffect(id:  "image-\(car.id)", in: ns)
                    .clipped()

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: . bottom
                    )
                    
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: . clear, location: 0.0),
                            . init(color: .white.opacity(0.22), location: 0.48),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    .opacity(0.28)
                    .blur(radius: 10)
                    .rotationEffect(. degrees(18))
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
                    .foregroundStyle(. white)
                    .matchedGeometryEffect(id:  "title-\(car.id)", in: ns)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if car.isJailbreak {
                            StatCapsule(label: "Jailbreak", value: "", tint: .purple)
                        } else if car.stage == 0 {
                            StatCapsule(label: "Stock", value: "", tint: . gray)
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

private func stageTint(for stage:  Int) -> Color {
    switch stage {
    case 1: return Color("EmpireMint")
    case 2: return . yellow
    case 3: return . red
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
            .rotationEffect(. degrees(isJiggling ? 1.8 : 0), anchor: .center)
            .animation(isJiggling ? . easeInOut(duration: 0.09).repeatForever(autoreverses: true) : .default, value: isJiggling)
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
                withAnimation(.linear(duration: 5.5).repeatForever(autoreverses:  false)) {
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
    let tint:  Color
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
        .padding(. horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(. ultraThinMaterial)
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
            .font(. caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            .foregroundStyle(.white)
    }
}

private struct GlassButton: View {
    let title: String
    var action: (() -> Void)?  = nil

    var body: some View {
        Button(action: { action?() }) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(. ultraThinMaterial)
                )
                .overlay(
                    Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
                .foregroundStyle(. white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color("EmpireMint").opacity(0.25), radius: 8, x: 0, y:  4)
    }
}

private struct HoloShimmerMask: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: . clear, location: 0.0),
                .init(color: . white.opacity(0.3), location: 0.45),
                .init(color: .clear, location: 0.9)
            ]),
            startPoint: .topLeading,
            endPoint:  .bottomTrailing
        )
        .scaleEffect(x: 1.8)
        .offset(x: -120 + phase * 240)
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        . blendMode(.screen)
        .opacity(0.6)
        .allowsHitTesting(false)
    }
}

private struct GalleryTile: View {
    let car: Car
    let isLiked: Bool
    let onToggleLike: () -> Void

    var body:  some View {
        ZStack(alignment: .topTrailing) {
         
            ZStack(alignment: .bottomLeading) {
                Image(car.imageName)
                    . resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        LinearGradient(colors: [. clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .allowsHitTesting(false)
                    )
                    . contentShape(Rectangle())

                // Metadata badges
                HStack(spacing: 8) {
                    if car.isJailbreak {
                        StatCapsule(label: "Jailbreak", value: "", tint: .purple)
                    } else if car.stage == 0 {
                        StatCapsule(label: "Stock", value: "", tint: . gray)
                    } else {
                        StatCapsule(label: "Stage", value: "\(car.stage)", tint: stageTint(for: car.stage))
                    }
                    StatCapsule(label:  "HP", value: "\(car.horsepower)", tint: .cyan)
                }
                .padding(10)
            }

            // Like button
            Button(action: { onToggleLike() }) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    . foregroundStyle(isLiked ? Color("EmpireMint") : . white)
                    .padding(8)
                    .background(
                        Circle().fill(. ultraThinMaterial)
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
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilt: CGSize = .zero

    var body: some View {
        ZStack {
            // Card base with glass and shimmer
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(. ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius:  28)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint:  .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .blendMode(.screen)
                )
                .overlay(HoloShimmerMask().clipShape(RoundedRectangle(cornerRadius: 28)).opacity(reduceMotion ? 0 : 1))
                .shadow(color: Color("EmpireMint").opacity(0.22), radius: 28, x: 0, y:  18)
                .matchedGeometryEffect(id:  "card-\(car.id)", in: ns)
                .rotation3DEffect(. degrees(Double(tilt.width) * 0.06), axis: (x:  0, y: 1, z: 0))
                .rotation3DEffect(.degrees(Double(-tilt.height) * 0.06), axis: (x: 1, y: 0, z:  0))

            // Embedded full-card image with parallax
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Group {
                        if let data = loadSavedPhotoData(for: car.id), let uiImage = UIImage(data:  data) {
                            Image(uiImage: uiImage)
                                .resizable()
                        } else {
                            Image(car.imageName)
                                .resizable()
                        }
                    }
                    . aspectRatio(contentMode: . fill)
                    .frame(width: size.width + (reduceMotion ? 0 : tilt.width * 0.4), height: size.height)
                    .opacity(0.5)
                    .matchedGeometryEffect(id: "image-\(car.id)", in: ns)
                    .accessibilityHidden(true)
                    .clipped()
                    .offset(x: reduceMotion ? 0 : tilt.width * 0.06, y: reduceMotion ?  0 : tilt.height * 0.04)

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
                        .font(.system(. title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)
                        .matchedGeometryEffect(id:  "title-\(car.id)", in: ns)

                    Text(car.description)
                        .font(.footnote)
                        .foregroundStyle(. white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 8)

                HStack(spacing: 10) {
                    if car.isJailbreak {
                        StatCapsule(label: "Jailbreak", value: "", tint: .purple)
                    } else if car.stage == 0 {
                        StatCapsule(label:  "Stock", value: "", tint: .gray)
                    } else {
                        StatCapsule(label: "Stage", value: "\(car.stage)", tint: stageTint(for:  car.stage))
                    }
                    StatCapsule(label: "HP", value: "\(car.horsepower)", tint: .cyan)
                }

                VStack(spacing: 10) {
                    StatRow(name: "Horsepower", value: Double(car.horsepower), max: 700, accent: Color("EmpireMint"))
                    StatRow(name: car.isJailbreak ? "Jailbreak" : (car.stage == 0 ?  "Stock" : "Stage"), value: Double(car.isJailbreak ? 1 : car.stage), max: car.isJailbreak ? 1 : 3, accent: car.isJailbreak ? . purple : stageTint(for: car.stage))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius:  16).fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [. white.opacity(0.25), .white.opacity(0.05)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )

                Spacer(minLength: 6)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        GlassButton(title: "Mods") { hapticTap() }
                        GlassButton(title: "Specs") { hapticTap() }
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
        .hoverEffect(. lift)
        #endif
    }
}

// MARK:  - Reusable Components
private struct Badge: View {
    let text:  String
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
            .foregroundStyle(. white)
    }
}

private struct StatRow: View {
    let name: String
    let value: Double
    let max:  Double
    let accent: Color

    @State private var animate:  Bool = false

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(. white.opacity(0.8))
                Spacer()
                Text(displayValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 6)
                    . fill(LinearGradient(colors: [accent.opacity(0.9), accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: animate ? barWidth : 0)
                    .shadow(color: accent.opacity(0.4), radius: 6, x: 0, y:  2)
            }
            .frame(height: 10)
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
        return max == 0 ? 0 :  Swift.min(value / max, 1)
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
    @State private var showHeartBurst:  Bool = false
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
                                . onTapGesture(count: 2) {
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

                            LinearGradient(colors: [. clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                                .frame(height: 220)
                                .ignoresSafeArea(edges: .bottom)

                            // Bottom metadata overlay
                            VStack(alignment: .leading, spacing: 8) {
                                Text(cars[i].name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(cars[i].description)
                                    .font(. caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(2)
                                HStack(spacing: 10) {
                                    if cars[i].isJailbreak {
                                        StatCapsule(label: "Jailbreak", value: "", tint: .purple)
                                    } else if cars[i].stage == 0 {
                                        StatCapsule(label: "Stock", value: "", tint: .gray)
                                    } else {
                                        StatCapsule(label:  "Stage", value: "\(cars[i].stage)", tint: stageTint(for: cars[i].stage))
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
            .tabViewStyle(. page(indexDisplayMode: .never))

            // Heart burst overlay
            if showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(Color("EmpireMint"))
                    .shadow(color: Color("EmpireMint").opacity(0.6), radius: 12)
                    .scaleEffect(heartScale)
                    .opacity(heartOpacity)
                    . transition(.scale.combined(with: .opacity))
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
                    } label:  {
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
                            Image(systemName: isLiked ?  "heart.fill" : "heart")
                                .foregroundStyle(isLiked ?  Color("EmpireMint") : . white)
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

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint:  .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .blendMode(.screen)
                )
                .overlay(HoloShimmerMask().clipShape(RoundedRectangle(cornerRadius: 28)).opacity(reduceMotion ? 0 : 1))
                .shadow(color: Color("EmpireMint").opacity(0.22), radius: 28, x: 0, y:  18)

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
                        .offset(x: reduceMotion ? 0 : tilt.width * 0.06, y: reduceMotion ? 0 :  tilt.height * 0.04)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.12),
                            Color.black.opacity(0.32)
                        ],
                        startPoint:  .top,
                        endPoint: . bottom
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

                HStack(spacing:  10) {
                    if car.isJailbreak {
                        StatCapsule(label: "Jailbreak", value: "", tint: .purple)
                    } else if car.stage == 0 {
                        StatCapsule(label: "Stock", value: "", tint: . gray)
                    } else {
                        StatCapsule(label: "Stage", value: "\(car.stage)", tint: stageTint(for: car.stage))
                    }
                    StatCapsule(label:  "HP", value: "\(car.horsepower)", tint: .cyan)
                }

                VStack(spacing: 10) {
                    StatRow(name: "Horsepower", value: Double(car.horsepower), max: 700, accent: Color("EmpireMint"))
                    StatRow(name: car.isJailbreak ? "Jailbreak" : (car.stage == 0 ?  "Stock" : "Stage"), value: Double(car.isJailbreak ? 1 : car.stage), max: car.isJailbreak ? 1 : 3, accent: car.isJailbreak ? .purple : stageTint(for: car.stage))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
                        . overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [. white.opacity(0.25), .white.opacity(0.05)],
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
                    . font(.system(size: 96))
                    .foregroundStyle(Color("EmpireMint"))
                    .shadow(color: Color("EmpireMint").opacity(0.6), radius: 12)
                    . transition(.scale.combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: . infinity, alignment: .center)
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
                        tilt = CGSize(width:  w, height: h)
                    }
                }
                . onEnded { _ in
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

// MARK: - Saved Photo Loader (per-user, per-car)
private func loadSavedPhotoData(for id: UUID) -> Data? {
    let currentUserId = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
    // Primary per-user key used by VehicleEditorView
    if let data = UserDefaults.standard.data(forKey: "saved_car_photo_\(currentUserId)_\(id.uuidString)") {
        return data
    }
    // Legacy fallback without user scoping
    if let legacy = UserDefaults.standard.data(forKey: "saved_car_photo_\(id.uuidString)") {
        return legacy
    }
    return nil
}
