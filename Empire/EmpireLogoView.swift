import SwiftUI

public struct EmpireLogoView: View {
    public enum Style {
        case tinted(Color)
        case original
    }

    private let size: CGFloat
    private let style: Style
    private let shimmer: Bool
    private let parallaxAmount: CGFloat

    public init(size: CGFloat = 200, style: Style = .tinted(EmpireTheme.mintCore), shimmer: Bool = true, parallaxAmount: CGFloat = 4) {
        self.size = size
        self.style = style
        self.shimmer = shimmer
        self.parallaxAmount = parallaxAmount
    }

    public var body: some View {
        let base = Image("empire_tp")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)

        let styled: some View = Group {
            switch style {
            case .tinted(let color):
                base
                    .renderingMode(.template)
                    .foregroundColor(color)
            case .original:
                base
            }
        }
        .shadow(color: EmpireTheme.mintCore.opacity(0.25), radius: 20, x: 0, y: 8)

        if shimmer {
            styled
                .empireShimmer(angle: .degrees(18), speed: 0.8, opacity: 0.25)
                .empireParallax(amount: parallaxAmount)
        } else {
            styled
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        EmpireLogoView()
        EmpireLogoView(size: 140, style: .original, shimmer: false)
        EmpireLogoView(size: 220, style: .tinted(.white))
    }
    .padding()
    .preferredColorScheme(.dark)
}
