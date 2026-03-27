import SwiftUI
import Combine
import SwiftData
import UIKit

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
            }
            .preferredColorScheme(.dark)
            .fullScreenCover(isPresented: Binding(get: { !authViewModel.isAuthenticated && !authViewModel.isLoading }, set: { _ in })) {
                LoginView()
                    .environmentObject(authViewModel)
                    .preferredColorScheme(.dark)
            }
            .id(authViewModel.isAuthenticated ? "auth" : "loggedOut")
            .onAppear {
                Self.normalizeLegacyCarPhotosIfNeeded()
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

private extension EmpireApp {
    static func normalizeLegacyCarPhotosIfNeeded() {
        let defaultsKey = "normalized_legacy_car_photos_v1"
        guard UserDefaults.standard.bool(forKey: defaultsKey) == false else { return }

        Task.detached(priority: .utility) {
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil) else { return }

            let targetURLs = fileURLs.filter { url in
                let name = url.lastPathComponent.lowercased()
                return name.hasPrefix("car_") && (name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") || name.hasSuffix(".png"))
            }

            for url in targetURLs {
                autoreleasepool {
                    guard let data = try? Data(contentsOf: url),
                          let image = UIImage(data: data),
                          let normalized = image.jpegData(compressionQuality: 0.96) else {
                        return
                    }
                    try? normalized.write(to: url, options: [.atomic])
                }
            }

            UserDefaults.standard.set(true, forKey: defaultsKey)
        }
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
