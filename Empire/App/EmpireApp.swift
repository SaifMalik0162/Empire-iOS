import SwiftUI
import Combine
import SwiftData
import UIKit
import GoogleSignIn
import UserNotifications
import Supabase
import PostgREST

@main
struct EmpireApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var cart = Cart()
    @StateObject private var vehiclesVM = UserVehiclesViewModel()
    @StateObject private var communityInboxVM = CommunityInboxViewModel()
    @StateObject private var appNavigation = AppNavigationModel.shared
    @StateObject private var pushNotifications = PushNotificationsManager.shared
    @UIApplicationDelegateAdaptor(EmpireAppDelegate.self) private var appDelegate
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var dismissObserver: AnyCancellable? = nil

    init() {
        AppTelemetry.shared.configure()
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: SupabaseConfig.googleClientID,
            serverClientID: SupabaseConfig.googleServerClientID
        )
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
                    .environmentObject(communityInboxVM)
                    .environmentObject(appNavigation)
                    .environmentObject(pushNotifications)
                    .fullScreenCover(isPresented: Binding(get: { authViewModel.shouldPromptAddVehicle }, set: { _ in })) {
                        EmpireAddVehicleView(vm: vehiclesVM)
                            .preferredColorScheme(.dark)
                    }
            }
            .preferredColorScheme(.dark)
            .fullScreenCover(isPresented: Binding(get: {
                !authViewModel.isAuthenticated &&
                !authViewModel.isLoading &&
                !authViewModel.isPresentingPasswordRecovery
            }, set: { _ in })) {
                LoginView()
                    .environmentObject(authViewModel)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: Binding(get: { authViewModel.isPresentingPasswordRecovery }, set: { newValue in
                if !newValue {
                    authViewModel.dismissPasswordRecovery()
                }
            })) {
                PasswordRecoveryView()
                    .environmentObject(authViewModel)
                    .preferredColorScheme(.dark)
            }
            .fullScreenCover(isPresented: Binding(get: { authViewModel.isPresentingOnboarding }, set: { newValue in
                if !newValue {
                    authViewModel.completeOnboarding()
                }
            })) {
                EmpireOnboardingView()
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
                Task { await communityInboxVM.refresh() }
                Task { await pushNotifications.handleAuthStateChanged(user: authViewModel.currentUser) }
            }
            .onDisappear {
                dismissObserver?.cancel()
                dismissObserver = nil
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                UNUserNotificationCenter.current().setBadgeCount(0)
                Task { await communityInboxVM.refresh() }
            }
            .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
                Task {
                    if isAuthenticated {
                        await communityInboxVM.refresh()
                    }
                    await pushNotifications.handleAuthStateChanged(user: authViewModel.currentUser)
                }
            }
            .onChange(of: authViewModel.currentUser) { _, newUser in
                Task { await pushNotifications.handleAuthStateChanged(user: newUser) }
            }
            .onOpenURL { url in
                if GIDSignIn.sharedInstance.handle(url) {
                    return
                }
                if appNavigation.handle(url: url) {
                    return
                }
                Task {
                    await authViewModel.handleIncomingURL(url)
                }
            }
        }
        .modelContainer(modelContainer)
    }
    
}

private final class EmpireAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { await PushNotificationsManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { await PushNotificationsManager.shared.didFailToRegisterForRemoteNotifications(error: error) }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        AppNavigationModel.shared.handle(userInfo: response.notification.request.content.userInfo)
    }
}

enum AppDeepLink: Equatable {
    case post(UUID)
    case profile(String)
    case meet(UUID)

    var preferredTab: EmpireTab {
        switch self {
        case .post, .profile:
            return .cars
        case .meet:
            return .meets
        }
    }
}

@MainActor
final class AppNavigationModel: ObservableObject {
    static let shared = AppNavigationModel()

    @Published var selectedTab: EmpireTab = .home
    @Published var pendingDeepLink: AppDeepLink? = nil

    private init() {}

    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme?.lowercased() == SupabaseConfig.appURLScheme.lowercased() else { return false }
        guard let deepLink = deepLink(from: url) else { return false }
        open(deepLink)
        return true
    }

    func handle(userInfo: [AnyHashable: Any]) {
        if let deepLinkString = userInfo["deep_link"] as? String ?? userInfo["deepLink"] as? String,
           let url = URL(string: deepLinkString) {
            _ = handle(url: url)
        }
    }

    func open(_ deepLink: AppDeepLink) {
        selectedTab = deepLink.preferredTab
        pendingDeepLink = deepLink
    }

    func consume(_ deepLink: AppDeepLink) {
        if pendingDeepLink == deepLink {
            pendingDeepLink = nil
        }
    }

    private func deepLink(from url: URL) -> AppDeepLink? {
        let host = (url.host ?? "").lowercased()
        let pathComponent = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch host {
        case "post":
            guard let id = UUID(uuidString: pathComponent) else { return nil }
            return .post(id)
        case "profile":
            guard !pathComponent.isEmpty else { return nil }
            return .profile(pathComponent)
        case "meet":
            guard let id = UUID(uuidString: pathComponent) else { return nil }
            return .meet(id)
        default:
            return nil
        }
    }
}

struct PushNotificationPreferences: Codable, Equatable {
    var likes: Bool = true
    var comments: Bool = true
    var follows: Bool = true
    var meets: Bool = true
}

@MainActor
final class PushNotificationsManager: ObservableObject {
    static let shared = PushNotificationsManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastRegistrationError: String? = nil
    @Published var preferences = PushNotificationPreferences()
    @Published private(set) var isSyncingPreferences = false

    private var currentDeviceToken: String? = nil
    private let client = SupabaseClientProvider.client

    private init() {
        Task { await refreshAuthorizationStatus() }
    }

    var authorizationSummary: String {
        switch authorizationStatus {
        case .authorized: return "Enabled"
        case .provisional: return "Provisional"
        case .ephemeral: return "Temporary"
        case .denied: return "Denied"
        case .notDetermined: return "Not Set"
        @unknown default: return "Unknown"
        }
    }

    func handleAuthStateChanged(user: BackendUser?) async {
        await refreshAuthorizationStatus()
        if user != nil {
            await refreshPreferences()
            await registerForRemoteNotificationsIfAuthorized()
            await syncCurrentDeviceTokenIfPossible()
        } else {
            preferences = PushNotificationPreferences()
        }
    }

    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            lastRegistrationError = error.localizedDescription
        }
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) async {
        currentDeviceToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        lastRegistrationError = nil
        await syncCurrentDeviceTokenIfPossible()
    }

    func didFailToRegisterForRemoteNotifications(error: Error) async {
        lastRegistrationError = error.localizedDescription
    }

    func refreshPreferences() async {
        guard let userUUID = currentUserUUID else {
            preferences = PushNotificationPreferences()
            return
        }

        isSyncingPreferences = true
        defer { isSyncingPreferences = false }

        do {
            let rows: [NotificationPreferencesRow] = try await client
                .from("notification_preferences")
                .select("user_id, likes, comments, follows, meets")
                .eq("user_id", value: userUUID)
                .limit(1)
                .execute()
                .value

            if let row = rows.first {
                preferences = row.preferences
            } else {
                let defaults = PushNotificationPreferences()
                try await savePreferences(defaults)
            }
        } catch {
            lastRegistrationError = error.localizedDescription
        }
    }

    func updatePreferences(_ updated: PushNotificationPreferences) async {
        preferences = updated
        do {
            try await savePreferences(updated)
            if updated.likes || updated.comments || updated.follows || updated.meets {
                await requestAuthorizationAndRegister()
            }
        } catch {
            lastRegistrationError = error.localizedDescription
        }
    }

    private func savePreferences(_ updated: PushNotificationPreferences) async throws {
        guard let userUUID = currentUserUUID else { return }
        let row = NotificationPreferencesRow(user_id: userUUID, likes: updated.likes, comments: updated.comments, follows: updated.follows, meets: updated.meets)
        _ = try await client
            .from("notification_preferences")
            .upsert(row, onConflict: "user_id")
            .execute()
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func registerForRemoteNotificationsIfAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func syncCurrentDeviceTokenIfPossible() async {
        guard let token = currentDeviceToken,
              let userUUID = currentUserUUID else { return }

        let row = PushDeviceTokenRow(
            user_id: userUUID,
            device_token: token,
            platform: "ios",
            environment: apnsEnvironment,
            bundle_id: Bundle.main.bundleIdentifier ?? "com.empireautoclub.empireconnect",
            is_active: true,
            last_seen_at: ISO8601DateFormatter().string(from: Date())
        )

        do {
            _ = try await client
                .from("user_push_tokens")
                .upsert(row, onConflict: "device_token")
                .execute()
        } catch {
            lastRegistrationError = error.localizedDescription
        }
    }

    private var currentUserUUID: UUID? {
        guard let raw = UserDefaults.standard.string(forKey: "currentUserId") else { return nil }
        return UUID(uuidString: raw)
    }

    private var apnsEnvironment: String {
        "development"
    }

    private var embeddedProvisionAPNsEnvironment: String? {
        guard let provisionURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let provisionData = try? Data(contentsOf: provisionURL),
              let provisionString = String(data: provisionData, encoding: .ascii),
              let plistStart = provisionString.range(of: "<plist"),
              let plistEnd = provisionString.range(of: "</plist>") else {
            return nil
        }

        let plistString = String(provisionString[plistStart.lowerBound..<plistEnd.upperBound])
        guard let plistData = plistString.data(using: .utf8),
              let plistObject = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
              let plist = plistObject as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let apsEnvironment = entitlements["aps-environment"] as? String else {
            return nil
        }

        switch apsEnvironment.lowercased() {
        case "development":
            return "development"
        case "production":
            return "production"
        default:
            return nil
        }
    }
}

private struct PushDeviceTokenRow: Encodable {
    let user_id: UUID
    let device_token: String
    let platform: String
    let environment: String
    let bundle_id: String
    let is_active: Bool
    let last_seen_at: String
}

private struct NotificationPreferencesRow: Codable {
    let user_id: UUID
    let likes: Bool
    let comments: Bool
    let follows: Bool
    let meets: Bool

    var preferences: PushNotificationPreferences {
        PushNotificationPreferences(likes: likes, comments: comments, follows: follows, meets: meets)
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
