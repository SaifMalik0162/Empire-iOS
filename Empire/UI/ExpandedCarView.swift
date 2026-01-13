import SwiftUI
import UIKit

struct ExpandedCarView: View {
    let car: Car
    @Namespace private var ns
    @State private var appear: Bool = false
    @State private var showSpecs: Bool = false
    @State private var showMods: Bool = false
    @State private var savedPhotoData: Data? = nil

    private var userStorageKey: String {
        UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
    }

    var body: some View {
        ZStack {
            // Dim + blur background for focus
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .blur(radius: 2)
                .transition(.opacity)

            CarExpandedCard(car: car, photoData: savedPhotoData, ns: ns, onClose: {}, showSpecs: $showSpecs, showMods: $showMods)
                .scaleEffect(appear ? 1.0 : 0.98)
                .opacity(appear ? 1.0 : 0.0)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: appear)
                .padding(.horizontal, 20)
            
            if showSpecs {
                PopupCard {
                    SpecsListView(specs: car.specs)
                } onClose: {
                    showSpecs = false
                }
            }
            
            if showMods {
                PopupCard {
                    ModsListView(mods: car.mods)
                } onClose: {
                    showMods = false
                }
            }
        }
        .onAppear {
            appear = true
            savedPhotoData = Self.loadSavedPhotoData(for: car.id, userKey: userStorageKey)
        }
        .onDisappear { appear = false }
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
            .background(Capsule().fill(color.opacity(0.18)))
            .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
            .foregroundStyle(.white)
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
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(tint.opacity(0.6), lineWidth: 1))
    }
}

@inline(__always)
private func hapticTap() {
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
}

struct CarExpandedCard: View {
    let car: Car
    let photoData: Data?
    var ns: Namespace.ID
    var onClose: () -> Void

    @Binding var showSpecs: Bool
    @Binding var showMods: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilt: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // Card base with glass and shimmer
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
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
                    .overlay(HoloShimmerMask().clipShape(RoundedRectangle(cornerRadius: 28)).opacity(reduceMotion ? 0 : 1))
                    .shadow(color: Color("EmpireMint").opacity(0.22), radius: 28, x: 0, y: 18)
                    .matchedGeometryEffect(id: "card-\(car.id)", in: ns)
                    .rotation3DEffect(.degrees(Double(tilt.width) * 0.06), axis: (x: 0, y: 1, z: 0))
                    .rotation3DEffect(.degrees(Double(-tilt.height) * 0.06), axis: (x: 1, y: 0, z: 0))

                // Hero image
                ZStack {
                    Group {
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                        } else {
                            Image(car.imageName)
                                .resizable()
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width + (reduceMotion ? 0 : tilt.width * 0.4), height: size.height * 0.42 + (reduceMotion ? 0 : tilt.height * 0.2))
                    .clipped()
                    .opacity(0.55)
                    .matchedGeometryEffect(id: "image-\(car.id)", in: ns)
                    .accessibilityHidden(true)
                    .offset(x: reduceMotion ? 0 : tilt.width * 0.06, y: reduceMotion ? 0 : tilt.height * 0.04)
                    .mask(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    )

                    // Frosted overlay to ensure legibility
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.0), Color.black.opacity(0.12), Color.black.opacity(0.32)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
                // Foreground content
                VStack(spacing: 14) {
                    // Glass top bar
                    HStack {
                        Badge(text: "Owner", color: Color("EmpireMint"))
                        Spacer()
                        // Space reserved for future controls
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .background(Color.clear)

                    // Title & subtitle
                    VStack(spacing: 6) {
                        Text(car.name)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                            .shadow(radius: 6)
                            .matchedGeometryEffect(id: "title-\(car.id)", in: ns)
                            .accessibilityLabel(Text("Car name: \(car.name)"))

                        Text(car.description)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .accessibilityLabel(Text("Description: \(car.description)"))
                    }
                    .padding(.top, 4)

                    // Compact badges
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

                    // Stat meters with unified animation
                    VStack(spacing: 10) {
                        LiquidStatRow(name: "Horsepower", value: Double(car.horsepower), max: 1200, accent: Color("EmpireMint"))
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
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .accessibilityElement(children: .contain)

                    Spacer(minLength: 8)

                    // Action buttons
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            GlassButton(title: "Edit") { hapticTap() }
                            GlassButton(title: "Mods") { hapticTap(); showMods = true }
                            GlassButton(title: "Specs") { hapticTap(); showSpecs = true }
                        }
                        HStack(spacing: 12) {
                            GlassButton(title: "Share") { hapticTap() }
                            GlassButton(title: "Export Card") { hapticTap() }
                        }
                    }
                    .padding(.bottom, 12)
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
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .onChanged { _ in
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                    }
            )
            #if os(iOS)
            .hoverEffect(.lift)
            #endif
        }
    }

    private func stageAccentColor() -> Color {
        if car.isJailbreak { return .purple }
        switch car.stage {
        case 0: return .gray
        case 1: return Color("EmpireMint")
        case 2: return .yellow
        case 3: return .red
        default: return .gray
        }
    }
    private func stageDisplayName() -> String {
        if car.isJailbreak { return "Jailbreak" }
        return car.stage == 0 ? "Stock" : "Stage"
    }
    private func stageDisplayValue() -> Int {
        if car.isJailbreak { return 1 }
        return car.stage
    }
    private func stageMax() -> Double {
        if car.isJailbreak { return 1 }
        return 3
    }
    private func stageBarTitle() -> String {
        if car.isJailbreak { return "Jailbreak" }
        if car.stage == 0 { return "Stock" }
        return "Stage"
    }
    private func stageBarValue() -> Int {
        if car.isJailbreak { return 1 }
        return car.stage
    }
    private func stageBarMax() -> Double {
        if car.isJailbreak { return 1 }
        return 3
    }
}

private struct LiquidStatRow: View {
    let name: String
    let value: Double
    let max: Double
    let accent: Color
    @State private var phase: CGFloat = 0

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
                // Liquid fill with animated wave
                GeometryReader { geo in
                    let width = geo.size.width * CGFloat(normalized)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(accent.opacity(0.35))
                            .frame(width: width)
                        LiquidWave(color: accent, amplitude: 4, wavelength: 40, phase: phase)
                            .frame(width: width, height: 10)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .blendMode(.plusLighter)
                    }
                }
                .frame(height: 10)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }

    private var normalized: Double { max == 0 ? 0 : min(value / max, 1) }
    private var displayValue: String {
        if name == "Horsepower" { return "\(Int(value)) HP" }
        if name.lowercased().contains("stage") { return "\(Int(value))" }
        return String(format: "%.0f", value)
    }
}

private struct LiquidWave: View {
    let color: Color
    let amplitude: CGFloat
    let wavelength: CGFloat
    let phase: CGFloat

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                var path = Path()
                let midY = size.height / 2
                let width = size.width
                let height = size.height
                path.move(to: CGPoint(x: 0, y: midY))
                let step: CGFloat = 2
                for x in stride(from: 0, through: width, by: step) {
                    let relative = x / wavelength
                    let y = midY + sin(relative * .pi * 2 + phase * .pi * 2) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
                context.fill(path, with: .linearGradient(Gradient(colors: [color.opacity(0.9), color.opacity(0.6)]), startPoint: .zero, endPoint: CGPoint(x: width, y: height)))
            }
        }
    }
}

private struct StatRow: View {
    let name: String
    let value: Double
    let max: Double
    let accent: Color

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
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.9), accent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: barWidth)
                    .shadow(color: accent.opacity(0.4), radius: 6, x: 0, y: 2)
            }
            .frame(height: 10)
        }
    }

    private var normalized: Double {
        if name == "Stage" || name == "Stock" || name == "Jailbreak" {
            let clamped = Swift.max(0, Swift.min(Int(value), Int(max)))
            return max == 0 ? 0 : Double(clamped) / max
        }
        return max == 0 ? 0 : Swift.min(value / max, 1)
    }
    private var barWidth: CGFloat { CGFloat(normalized) * 220 }
    private var displayValue: String {
        if name == "Horsepower" { return "\(Int(value)) HP" }
        if name == "Jailbreak" { return "Jailbreak" }
        if name == "Stock" { return "Stock" }
        if name == "Stage" { return "\(Int(value))" }
        return String(format: "%.0f", value)
    }
}

private struct GlassButton: View {
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            Text(title)
                .font(.caption.weight(.semibold))
                .accessibilityLabel(Text(title))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
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
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color("EmpireMint").opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

private struct HoloShimmerMask: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
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
        .opacity(accessibilityReduceMotion ? 0.0 : 0.6)
        .allowsHitTesting(false)
    }
}

private struct SpecsListView: View {
    let specs: [SpecItem]
    var body: some View {
        NavigationStack {
            List {
                if specs.isEmpty {
                    Section {
                        Text("No specs added yet").foregroundColor(.secondary)
                    }
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
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ModsListView: View {
    let mods: [ModItem]
    var body: some View {
        NavigationStack {
            List {
                if mods.isEmpty {
                    Section {
                        Text("No mods added yet").foregroundColor(.secondary)
                    }
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
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Saved photo lookup (matches VehicleEditorView keys)

private extension ExpandedCarView {
    static func loadSavedPhotoData(for id: UUID, userKey: String) -> Data? {
        UserDefaults.standard.data(forKey: "saved_car_photo_\(userKey)_\(id.uuidString)")
    }
}

struct ExpandedCarView_Previews: PreviewProvider {
    static var previews: some View {
        ExpandedCarView(car: Car(name: "Preview Car", description: "Stage 2 - Tuned", imageName: "car1", horsepower: 420, stage: 2))
            .preferredColorScheme(.dark)
    }
}

private struct PopupCard<Content: View>: View {
    @ViewBuilder var content: Content
    var onClose: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .transition(.opacity)
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    content
                        .padding(14)
                }
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
                .frame(maxWidth: 520)
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
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
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

private struct GalleryTile: View {
    let car: Car
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(car.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
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
                StatRow(
                    name: car.isJailbreak ? "Jailbreak" : (car.stage == 0 ? "Stock" : "Stage"),
                    value: Double(car.isJailbreak ? 1 : car.stage),
                    max: car.isJailbreak ? 1 : 3,
                    accent: car.isJailbreak ? .purple : stageTint(for: car.stage)
                )
            }
            .padding(10)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
        }
    }
}
