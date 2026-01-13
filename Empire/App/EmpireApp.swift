import SwiftUI
import Combine

@main
struct EmpireApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var cart = Cart()
    @StateObject private var vehiclesVM = UserVehiclesViewModel()
    
    @Environment(\.dismiss) private var dismiss
    @State private var dismissObserver: AnyCancellable? = nil
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                EmpireTabView()
                    .environmentObject(authViewModel)
                    .environmentObject(cart)
                    .fullScreenCover(isPresented: Binding(get: { authViewModel.shouldPromptAddVehicle }, set: { _ in })) {
                        EmpireAddVehicleView(vm: vehiclesVM)
                            .preferredColorScheme(.dark)
                    }
                if authViewModel.isLoading {
                    EmpireSplashView()
                }
            }
            .preferredColorScheme(.dark)
            .fullScreenCover(isPresented: Binding(get: { !authViewModel.isAuthenticated && !authViewModel.isLoading }, set: { _ in })) {
                LoginView()
                    .environmentObject(authViewModel)
                    .preferredColorScheme(.dark)
            }
            .id(authViewModel.isAuthenticated ? "auth" : "loggedOut")
            .onAppear {
                dismissObserver = NotificationCenter.default.publisher(for: .empireRequestDismiss)
                    .receive(on: RunLoop.main)
                    .sink { _ in
                        dismiss()
                    }
            }
            .onDisappear {
                dismissObserver?.cancel()
                dismissObserver = nil
            }
        }
    }
    
}
