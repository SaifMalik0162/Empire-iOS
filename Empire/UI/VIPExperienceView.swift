import SwiftUI

struct VIPExperienceView: View {
    @StateObject private var store = StoreKitManager.shared
    @State private var showWelcome = false
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.isVIP {
                    VIPDashboardView()
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    VIPJoinView()
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .navigationDestination(for: String.self) { route in
                if route == "dashboard" { VIPDashboardView() }
            }
        }
        .onChange(of: store.isVIP) { _, new in
            if new {
                // Transition: show welcome then push dashboard
                showWelcome = true
            }
        }
        .fullScreenCover(isPresented: $showWelcome) {
            VIPWelcomeView {
                showWelcome = false
                // After welcome, ensure we are on dashboard
                if !store.isVIP {
                    // Fallback: in case state changed back, do nothing
                } else {
                    // If currently on Join view, push dashboard via path
                    path = ["dashboard"]
                }
            }
        }
        .task { await store.loadProducts() }
    }
}

#Preview {
    VIPExperienceView()
}
