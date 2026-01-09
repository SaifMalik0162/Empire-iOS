import SwiftUI
import AVKit

struct EmpireSplashView: View {

    @State private var showLogin = false
    @State private var spin = false
    @State private var fadeOut = false

    var body: some View {
        ZStack {
            if showLogin {
                LoginView()
                    .transition(.opacity)
            } else {
                ZStack {
                    // Background
                    Color.black.ignoresSafeArea()
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: EmpireTheme.mintCore.opacity(0.22), location: 0.0),
                            .init(color: .clear, location: 1.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 520
                    )
                    .blur(radius: 40)
                    .allowsHitTesting(false)

                    // Glowing spinning logo
                    EmpireLogoView(size: 260, style: .tinted(EmpireTheme.mintCore), shimmer: false, parallaxAmount: 0)
                        .rotation3DEffect(.degrees(spin ? 360 : 0), axis: (x: 0.0, y: 1.0, z: 0.0))
                        .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: spin)
                        .overlay(
                            Circle()
                                .fill(EmpireTheme.mintCore.opacity(0.24))
                                .frame(width: 380, height: 380)
                                .blur(radius: 60)
                        )
                        .opacity(fadeOut ? 0 : 1)
                        .onAppear {
                            spin = true
                            // fade out before transition
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    fadeOut = true
                                }
                            }
                            // transition to login
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
                                withAnimation(.easeOut(duration: 0.35)) {
                                    showLogin = true
                                }
                            }
                        }
                }
            }
        }
        .background(Color.black)
    }
}
