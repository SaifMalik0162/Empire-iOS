import SwiftUI

struct EmpireTheme {
    // Core mint colors
    static let mintCore = Color(red: 0.10, green: 0.80, blue: 0.70)
    static let mintTeal = Color(red: 0.05, green: 0.60, blue: 0.70)
    static let mintDeep = Color(red: 0.00, green: 0.35, blue: 0.55)

    static var mintAdaptive: Color { Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.80, blue: 0.70, alpha: 1.0) : UIColor(red: 0.12, green: 0.78, blue: 0.68, alpha: 1.0)
    }) }

    // MARK: - Background gradients to avoid "X" artifacts
    // Asymmetric radial gradient reduces linear crossovers that create visible X patterns
    static func mintBackgroundGradient(center: UnitPoint = .init(x: 0.45, y: 0.42), startRadius: CGFloat = 20, endRadius: CGFloat = 600) -> RadialGradient {
        let c0 = Color.black
        let c1 = mintDeep.opacity(0.85)
        let c2 = mintTeal.opacity(0.70)
        let c3 = mintCore.opacity(0.55)
        let c4 = Color.black.opacity(0.95)
        // Non-symmetric stops: push mint energy off-center to avoid cross-banding
        return RadialGradient(
            gradient: Gradient(stops: [
                .init(color: c0, location: 0.00),
                .init(color: c1, location: 0.14),
                .init(color: c2, location: 0.39),
                .init(color: c3, location: 0.67),
                .init(color: c4, location: 1.00)
            ]),
            center: center,
            startRadius: startRadius,
            endRadius: endRadius
        )
    }

    // Angular variant for subtle rotational motion without crossing seams
    static func mintAngularBackgroundGradient(center: UnitPoint = .init(x: 0.48, y: 0.44), angle: Angle = .degrees(0)) -> AngularGradient {
        // Use a slight bias toward teal/mint and avoid a symmetric loop-back
        let c1 = mintDeep.opacity(0.80)
        let c2 = mintTeal.opacity(0.75)
        let c3 = mintCore.opacity(0.60)
        let c4 = Color.black.opacity(0.90)
        return AngularGradient(
            gradient: Gradient(stops: [
                .init(color: c1, location: 0.00),
                .init(color: c2, location: 0.28),
                .init(color: c3, location: 0.56),
                .init(color: c4, location: 0.92),
                .init(color: c1, location: 1.00) // wrap smoothly back to deep teal
            ]),
            center: center,
            angle: angle
        )
    }

    // Optional subtle noise overlay to mask banding on large smooth gradients
    @ViewBuilder
    static func backgroundWithNoise<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            content()
            Rectangle()
                .fill(Color.white.opacity(0.015))
                .blendMode(.overlay)
        }
    }

    // New mint + teal gradient colors
    static var mintTealGradientColors: [Color] {
        [
            Color(red: 0.10, green: 0.80, blue: 0.70), // mint core
            Color(red: 0.05, green: 0.60, blue: 0.70), // teal blend
            Color(red: 0.00, green: 0.45, blue: 0.60), // deeper teal
            Color(red: 0.10, green: 0.80, blue: 0.70)  // loop back to mint
        ]
    }

    static func mintTealGradient(start: UnitPoint, end: UnitPoint) -> LinearGradient {
        LinearGradient(colors: mintTealGradientColors, startPoint: start, endPoint: end)
    }

    // Reusable animated gradient colors
    static var mintGradientColors: [Color] {
        [Color.black, mintCore, Color.black, mintCore.opacity(0.85), Color.black]
    }

    // Darker variant convenience gradient colors
    static var mintDarkGradientColors: [Color] {
        [Color.black, mintCore, Color.black, mintCore.opacity(0.85), Color.black]
    }

    // Convenience gradient view
    static func mintGradient(start: UnitPoint, end: UnitPoint) -> LinearGradient {
        LinearGradient(colors: mintGradientColors, startPoint: start, endPoint: end)
    }

    // Darker variant convenience gradient view
    static func mintDarkGradient(start: UnitPoint, end: UnitPoint) -> LinearGradient {
        LinearGradient(colors: mintDarkGradientColors, startPoint: start, endPoint: end)
    }
}

// MARK: - View helpers
extension View {
    // Mint glass stroke for cards/fields
    func empireMintGlassStroke(cornerRadius: CGFloat = 16, lineWidth: CGFloat = 1.25) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(EmpireTheme.mintCore.opacity(0.28), lineWidth: lineWidth)
        )
    }

    // Subtle mint shadow for elevated elements
    func empireMintShadow(radius: CGFloat = 10, x: CGFloat = 0, y: CGFloat = 5, opacity: Double = 0.6) -> some View {
        self.shadow(color: EmpireTheme.mintCore.opacity(opacity), radius: radius, x: x, y: y)
    }

    // Soft mint glow behind an element
    func empireMintGlow(radius: CGFloat = 40, opacity: Double = 0.25) -> some View {
        self.background(
            Circle()
                .fill(EmpireTheme.mintCore.opacity(opacity))
                .blur(radius: radius)
        )
    }

    func empireShimmer(angle: Angle = .degrees(20), speed: Double = 0.9, opacity: Double = 0.35) -> some View {
        self.overlay(
            LinearGradient(colors: [Color.white.opacity(0.0), Color.white.opacity(opacity), Color.white.opacity(0.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .rotationEffect(angle)
                .mask(self)
                .modifier(_ShimmerModifier(speed: speed))
        )
    }

    func empireParallax(amount: CGFloat = 8) -> some View {
        #if os(iOS)
        return self.modifier(_ParallaxMotion(amount: amount))
        #else
        return self
        #endif
    }
}

private struct _ShimmerModifier: ViewModifier {
    let speed: Double
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(colors: [.black.opacity(0.0), .black, .black.opacity(0.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .offset(x: phase * 200)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5 / max(speed, 0.1)).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

#if os(iOS)
import CoreMotion
private struct _ParallaxMotion: ViewModifier {
    let amount: CGFloat
    @State private var x: CGFloat = 0
    @State private var y: CGFloat = 0
    private let motion = CMMotionManager()
    func body(content: Content) -> some View {
        content
            .offset(x: x, y: y)
            .onAppear {
                guard motion.isDeviceMotionAvailable else { return }
                motion.deviceMotionUpdateInterval = 1.0 / 30.0
                motion.startDeviceMotionUpdates(to: .main) { data, _ in
                    guard let data = data else { return }
                    let roll = data.attitude.roll
                    let pitch = data.attitude.pitch
                    x = CGFloat(roll) * amount
                    y = CGFloat(pitch) * amount
                }
            }
            .onDisappear {
                motion.stopDeviceMotionUpdates()
            }
    }
}
#endif
