import SwiftUI
public struct EmpireInteractiveBackground: View {
    @State private var t1: CGFloat = 0
    @State private var t2: CGFloat = 0
    @State private var t3: CGFloat = 0
    @State private var animate = false
    public init() {}
    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Cloud-like mint plasma using multiple animated radial gradients
            ZStack {
                blob(phase: t1, radius: 280, xAmp: 140, yAmp: 160, speed: 12, baseOpacity: 0.22)
                blob(phase: t2, radius: 240, xAmp: -150, yAmp: 130, speed: 14, baseOpacity: 0.18)
                blob(phase: t3, radius: 300, xAmp: 160, yAmp: -140, speed: 16, baseOpacity: 0.16)
            }
            .compositingGroup()
            .blendMode(.plusLighter) // preserves glow when blobs overlap
        }
        .ignoresSafeArea()
        .onAppear {
            animate = true
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { t1 = 2 * .pi }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { t2 = 2 * .pi }
            withAnimation(.linear(duration: 16).repeatForever(autoreverses: false)) { t3 = 2 * .pi }
        }
    }

    @ViewBuilder
    private func blob(phase: CGFloat, radius: CGFloat, xAmp: CGFloat, yAmp: CGFloat, speed: Double, baseOpacity: Double) -> some View {
        let x = sin(phase) * xAmp
        let y = cos(phase * 0.9) * yAmp
        RadialGradient(colors: [Color.mint.opacity(baseOpacity), .clear], center: .center, startRadius: 0, endRadius: radius)
            .frame(width: radius * 2, height: radius * 2)
            .offset(x: x, y: y)
            .blur(radius: 26)
    }
}
