import SwiftUI
import AVKit

struct EmpireSplashView: View {

    @State private var showMainApp = false
    @State private var fadeOut = false

    private let player: AVPlayer = {
        guard let url = Bundle.main.url(forResource: "empire 360", withExtension: "mp4") else {
            fatalError("File not found")
        }
        return AVPlayer(url: url)
    }()

    var body: some View {
        ZStack {
            if showMainApp {
                EmpireTabView()
                    .transition(.opacity)
            } else {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .opacity(fadeOut ? 0 : 1)
                    .onAppear {
                        player.seek(to: .zero)
                        player.play()

                        // Fade out
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                fadeOut = true
                            }
                        }

                        // Transition to app
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
                            withAnimation(.easeOut(duration: 0.35)) {
                                showMainApp = true
                            }

                            player.pause()
                            player.replaceCurrentItem(with: nil)
                        }
                    }
            }
        }
        .background(Color.black)
    }
}
