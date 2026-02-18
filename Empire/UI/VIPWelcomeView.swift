import SwiftUI

struct VIPWelcomeView: View {
    var onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var animate = false
    @State private var confetti = (0..<40).map { _ in UUID() }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.08, green: 0.08, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Confetti particles
            ZStack {
                ForEach(confetti, id: \.self) { id in
                    ConfettiPiece()
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(.yellow.opacity(0.15))
                        .frame(width: animate ? 220 : 140, height: animate ? 220 : 140)
                        .blur(radius: 16)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animate)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 96))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.8), radius: 20, x: 0, y: 10)
                        .scaleEffect(animate ? 1.0 : 0.85)
                        .rotationEffect(.degrees(animate ? 0 : -8))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).repeatForever(autoreverses: true), value: animate)
                }

                Text("Welcome to Empire VIP")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("You now have access to exclusive perks and a premium experience.")
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    dismiss()
                    onContinue()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right")
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.yellow, Color.yellow.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Capsule())
                    .foregroundStyle(.black)
                    .shadow(color: .yellow.opacity(0.6), radius: 16, x: 0, y: 10)
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .onAppear { animate = true }
    }
}

private struct ConfettiPiece: View {
    @State private var x: CGFloat = .random(in: -180...180)
    @State private var y: CGFloat = .random(in: -420...(-120))
    @State private var size: CGFloat = .random(in: 6...12)
    @State private var hue: Double = .random(in: 0.12...0.18)
    @State private var rotate: Double = .random(in: 0...360)

    var body: some View {
        GeometryReader { proxy in
            let midX = proxy.size.width / 2
            let maxY = proxy.size.height
            Rectangle()
                .fill(Color(hue: hue, saturation: 0.9, brightness: 1.0))
                .frame(width: size, height: size * .random(in: 1.0...2.0))
                .rotationEffect(.degrees(rotate))
                .position(x: midX + x, y: y)
                .onAppear {
                    withAnimation(.linear(duration: .random(in: 3.0...5.0)).repeatForever(autoreverses: false)) {
                        y = maxY + 60
                        rotate += .random(in: 180...540)
                    }
                }
        }
    }
}

#Preview {
    VIPWelcomeView(onContinue: {})
}
