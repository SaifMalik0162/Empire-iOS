import SwiftUI
import Combine
import SwiftData
import UIKit

@main
struct EmpireApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var cart = Cart()
    @StateObject private var vehiclesVM = UserVehiclesViewModel()
    
    @Environment(\.dismiss) private var dismiss
    @State private var dismissObserver: AnyCancellable? = nil

    init() {
        AppTelemetry.shared.configure()
        self.modelContainer = Self.makeModelContainer()
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
        .modelContainer(modelContainer)
    }
    
}

private extension EmpireApp {
    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            CarEntity.self,
            SpecItemEntity.self,
            ModItemEntity.self,
            MerchItemEntity.self
        ])

        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let storeDirectory = appSupportURL.appendingPathComponent("Empire", isDirectory: true)
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            let storeURL = storeDirectory.appendingPathComponent("default.store")
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData model container: \(error)")
        }
    }

    static func normalizeLegacyCarPhotosIfNeeded() {
        let defaultsKey = "normalized_legacy_car_photos_v1"
        guard UserDefaults.standard.bool(forKey: defaultsKey) == false else { return }
        // Legacy photo normalization used to rewrite every local car photo as JPEG
        // on launch. That showed up in profiling as avoidable JPEG encode work, so
        // we mark the migration complete without touching existing files.
        UserDefaults.standard.set(true, forKey: defaultsKey)
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
