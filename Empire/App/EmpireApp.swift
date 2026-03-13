import SwiftUI
import Combine
import SwiftData

@main
struct EmpireApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var cart = Cart()
    @StateObject private var vehiclesVM = UserVehiclesViewModel()
    
    @Environment(\.dismiss) private var dismiss
    @State private var dismissObserver: AnyCancellable? = nil

    init() {
        AppTelemetry.shared.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContextBridge { context in
                    vehiclesVM.setContext(context)
                    authViewModel.setModelContext(context)
                }
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
        .modelContainer(for: [CarEntity.self, SpecItemEntity.self, ModItemEntity.self, MerchItemEntity.self])
    }
    
}

fileprivate struct ContextBridge: View {
    @Environment(\.modelContext) private var modelContext
    var onReady: (ModelContext) -> Void
    init(_ onReady: @escaping (ModelContext) -> Void) { self.onReady = onReady }
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { onReady(modelContext) }
            .accessibilityHidden(true)
    }
}
