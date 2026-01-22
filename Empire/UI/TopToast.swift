import SwiftUI

public struct TopToast: View {
    public let text: String
    public init(text: String) { self.text = text }
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color("EmpireMint"))
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        )
        .shadow(color: Color("EmpireMint").opacity(0.25), radius: 18, x: 0, y: 8)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TopToast(text: "Added \"Sample Item\" to cart")
    }
    .preferredColorScheme(.dark)
}
