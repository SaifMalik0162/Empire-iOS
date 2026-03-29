import SwiftUI

struct EmpireTheme {
    // Core mint colors
    static let mintCore = Color("EmpireMint")
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let speed: Double
    @State private var phase: CGFloat = -1
    @State private var isAnimating = false

    private var animationsEnabled: Bool {
        scenePhase == .active && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    func body(content: Content) -> some View {
        content
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(colors: [.black.opacity(0.0), .black, .black.opacity(0.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .offset(x: phase * 200)
            )
            .onAppear { updateAnimationState() }
            .onChange(of: animationsEnabled) { _, _ in updateAnimationState() }
            .onDisappear { stopAnimation() }
    }

    private func updateAnimationState() {
        animationsEnabled ? startAnimation() : stopAnimation()
    }

    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        phase = -1
        withAnimation(.linear(duration: 1.5 / max(speed, 0.1)).repeatForever(autoreverses: false)) {
            phase = 1.2
        }
    }

    private func stopAnimation() {
        guard isAnimating || phase != -1 else { return }
        isAnimating = false
        phase = -1
    }
}

#if os(iOS)
import CoreMotion
private struct _ParallaxMotion: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let amount: CGFloat
    @State private var x: CGFloat = 0
    @State private var y: CGFloat = 0
    private let motion = CMMotionManager()

    private var animationsEnabled: Bool {
        scenePhase == .active && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    func body(content: Content) -> some View {
        content
            .offset(x: x, y: y)
            .onAppear { updateMotionState() }
            .onChange(of: animationsEnabled) { _, _ in updateMotionState() }
            .onDisappear { stopMotionUpdates() }
    }

    private func updateMotionState() {
        guard animationsEnabled, motion.isDeviceMotionAvailable else {
            stopMotionUpdates()
            return
        }

        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        guard motion.isDeviceMotionActive == false else { return }
        motion.startDeviceMotionUpdates(to: .main) { data, _ in
            guard let data = data else { return }
            let roll = data.attitude.roll
            let pitch = data.attitude.pitch
            x = CGFloat(roll) * amount
            y = CGFloat(pitch) * amount
        }
    }

    private func stopMotionUpdates() {
        motion.stopDeviceMotionUpdates()
        x = 0
        y = 0
    }
}
#endif

enum AuthPalette {
    static let background = Color(red: 0.02, green: 0.03, blue: 0.04)
    static let elevatedSurface = Color.white.opacity(0.12)
    static let border = EmpireTheme.mintCore.opacity(0.34)
    static let borderStrong = EmpireTheme.mintCore.opacity(0.6)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textMuted = Color.white.opacity(0.52)
    static let destructive = Color(red: 1.0, green: 0.43, blue: 0.43)
    static let success = Color(red: 0.52, green: 0.94, blue: 0.76)
}

struct AuthBackdrop: View {
    var body: some View {
        ZStack {
            AuthPalette.background
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color("EmpireMint").opacity(0.24),
                    Color("EmpireMint").opacity(0.08),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 380
            )
            .blur(radius: 28)
            .offset(x: 110, y: -170)

            RadialGradient(
                colors: [
                    Color("EmpireMint").opacity(0.16),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 320
            )
            .blur(radius: 30)
            .offset(x: -110, y: 210)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear,
                    Color.black.opacity(0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .ignoresSafeArea()
        }
    }
}

struct AuthScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            AuthBackdrop()
            content
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .frame(maxWidth: 470)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .preferredColorScheme(.dark)
    }
}

struct AuthPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.045),
                                    Color.white.opacity(0.015)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color("EmpireMint").opacity(0.18), radius: 16, y: 8)
    }
}

struct AuthHeader: View {
    let title: String
    let subtitle: String
    let logoSize: CGFloat

    init(title: String, subtitle: String, logoSize: CGFloat = 96) {
        self.title = title
        self.subtitle = subtitle
        self.logoSize = logoSize
    }

    var body: some View {
        VStack(spacing: 8) {
            EmpireLogoView(size: logoSize, style: .tinted(EmpireTheme.mintCore), shimmer: true, parallaxAmount: 0)
                .shadow(color: Color("EmpireMint").opacity(0.18), radius: 18, x: 0, y: 8)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AuthPalette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AuthPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.92)
            }
        }
    }
}

struct AuthField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var isSecure = false
    var revealSecureText = false
    var onToggleSecure: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AuthPalette.textMuted)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(EmpireTheme.mintCore.opacity(0.92))
                    .frame(width: 18)

                Group {
                    if isSecure && !revealSecureText {
                        SecureField(title, text: $text)
                    } else {
                        TextField(title, text: $text)
                    }
                }
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .foregroundStyle(AuthPalette.textPrimary)
                .tint(EmpireTheme.mintCore)

                if let onToggleSecure {
                    Button(action: onToggleSecure) {
                        Image(systemName: revealSecureText ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AuthPalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.08),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
}

struct AuthPrimaryButton: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("EmpireMint").opacity(0.96),
                                Color("EmpireMint").opacity(0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .foregroundStyle(Color.black.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color("EmpireMint").opacity(0.22), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1)
    }
}

struct AuthSocialButton<Leading: View>: View {
    let title: String
    var foreground: Color = .white
    let leading: Leading
    let action: () -> Void

    init(
        title: String,
        foreground: Color = .white,
        @ViewBuilder leading: () -> Leading,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.foreground = foreground
        self.leading = leading()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Spacer(minLength: 0)

                leading
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.92)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct AuthDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 14) {
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AuthPalette.textMuted)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

struct AuthMessage: View {
    let text: String
    let tone: Tone

    enum Tone {
        case error
        case success

        var color: Color {
            switch self {
            case .error:
                return AuthPalette.destructive
            case .success:
                return AuthPalette.success
            }
        }

        var icon: String {
            switch self {
            case .error:
                return "exclamationmark.triangle.fill"
            case .success:
                return "checkmark.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tone.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tone.color)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.9))
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tone.color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tone.color.opacity(0.32), lineWidth: 1)
        )
    }
}
