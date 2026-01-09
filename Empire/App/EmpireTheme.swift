import SwiftUI

struct EmpireTheme {
    // Core mint colors
    static let mintCore = Color(red: 0.10, green: 0.80, blue: 0.70)
    static let mintTeal = Color(red: 0.05, green: 0.60, blue: 0.70)
    static let mintDeep = Color(red: 0.00, green: 0.35, blue: 0.55)

    // Reusable animated gradient colors
    static var mintGradientColors: [Color] {
        [mintCore, mintTeal, mintDeep, mintCore]
    }

    // Convenience gradient view
    static func mintGradient(start: UnitPoint, end: UnitPoint) -> LinearGradient {
        LinearGradient(colors: mintGradientColors, startPoint: start, endPoint: end)
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
}
