import Foundation
import SwiftUI
import Combine
import Supabase
import SwiftData

protocol AuthServiceProviding {
    func hasValidSession() async throws -> Bool
    func currentUser() async throws -> BackendUser?
    func login(email: String, password: String) async throws -> BackendUser
    func loginWithGoogle(idToken: String, accessToken: String?, nonce: String?) async throws -> BackendUser
    func loginWithApple(idToken: String, nonce: String, suggestedUsername: String?) async throws -> BackendUser
    func beginPasswordRecovery(from url: URL) async throws -> Bool
    func completeAuthCallback(from url: URL) async throws -> BackendUser?
    func completePasswordReset(newPassword: String) async throws
    func sendPasswordReset(email: String) async throws
    func register(email: String, password: String, username: String) async throws -> BackendUser
    func logout() async throws
    func updateAvatarPath(_ avatarPath: String) async throws -> BackendUser
    func uploadAvatar(imageData: Data) async throws -> BackendUser
    func updateUsername(_ username: String) async throws -> BackendUser
}

protocol CarsServiceProviding {
    func fetchCars(for userId: String) async throws -> [Car]
}

extension SupabaseAuthService: AuthServiceProviding {}
extension SupabaseCarsService: CarsServiceProviding {}

@MainActor class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: BackendUser?
    @Published var isLoading = true
    @Published var shouldPromptAddVehicle: Bool = false
    @Published var isPresentingPasswordRecovery = false
    @Published var isPresentingOnboarding = false
    let instanceID = UUID()
    
    private let supabaseAuth: AuthServiceProviding
    private let carsService: CarsServiceProviding
    
    private var modelContext: ModelContext? = nil
    private var syncCarsTask: Task<Void, Never>? = nil
    private var authStateObserverTask: Task<Void, Never>? = nil
    private var lastCarsSyncAt: Date? = nil
    
    private let userDefaultsUserKey = "currentUser"
    private let onboardingVersion = "v1"

    static func normalizedSignupEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func persistCurrentUser(_ user: BackendUser?) {
        if let user {
            if let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: userDefaultsUserKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsUserKey)
        }
    }

    private func restoreCurrentUser() -> BackendUser? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsUserKey) else { return nil }
        return try? JSONDecoder().decode(BackendUser.self, from: data)
    }

    private func onboardingKey(for userId: String) -> String {
        "has_seen_onboarding_\(onboardingVersion)_\(userId.lowercased())"
    }

    private func updateAuthenticatedState(with user: BackendUser) {
        currentUser = user
        isAuthenticated = true
        UserDefaults.standard.set(user.id, forKey: "currentUserId")
        persistCurrentUser(user)
        evaluateOnboardingPresentation(for: user.id)
    }

    private func clearAuthenticatedState() {
        currentUser = nil
        isAuthenticated = false
        shouldPromptAddVehicle = false
        isPresentingOnboarding = false
        persistCurrentUser(nil)
        UserDefaults.standard.removeObject(forKey: "currentUserId")
    }

    private func evaluateOnboardingPresentation(for userId: String) {
        let hasSeen = UserDefaults.standard.bool(forKey: onboardingKey(for: userId))
        isPresentingOnboarding = !hasSeen
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        if isAuthenticated, let userId = currentUser?.id {
            scheduleCarsSync(userId: userId, force: false)
        }
    }
    
    init(
        authService: AuthServiceProviding? = nil,
        carsService: CarsServiceProviding? = nil,
        autoCheckStatus: Bool = true
    ) {
        self.supabaseAuth = authService ?? SupabaseAuthService()
        self.carsService = carsService ?? SupabaseCarsService()
        if authService == nil {
            observeAuthStateChanges()
        }
        print("[AuthVM] init: instanceID=\(instanceID)")
        if autoCheckStatus {
            Task {
                await checkAuthStatus()
            }
        }
    }
    
    func checkAuthStatus() async {
        print("[AuthVM] checkAuthStatus() start: isLoading(before)=\(isLoading)")
        AppTelemetry.shared.track(event: "auth.check_status.started")
        isLoading = true
        print("[AuthVM] checkAuthStatus() set isLoading=true")

        do {
            if try await supabaseAuth.hasValidSession(), let backendUser = try await supabaseAuth.currentUser() {
                updateAuthenticatedState(with: backendUser)
                await self.syncCarsFromBackend(userId: backendUser.id, force: false)
                AppTelemetry.shared.track(event: "auth.check_status.authenticated", metadata: ["userId": backendUser.id])
            } else {
                clearAuthenticatedState()
                AppTelemetry.shared.track(event: "auth.check_status.unauthenticated")
            }
        } catch {
            clearAuthenticatedState()
            AppTelemetry.shared.record(error: error, context: "auth.check_status")
        }

        isLoading = false
        print("[AuthVM] checkAuthStatus() end: isAuthenticated=\(isAuthenticated), isLoading=\(isLoading)")
    }
    
    func login(email: String, password: String) async throws {
        let user = try await AppTelemetry.shared.measure(operation: "auth.login") {
            try await supabaseAuth.login(email: email, password: password)
        }
        
        await MainActor.run { self.updateAuthenticatedState(with: user) }
        
        await self.syncCarsFromBackend(userId: user.id, force: true)
        
        await MainActor.run {
            self.shouldPromptAddVehicle = false
        }
        AppTelemetry.shared.track(event: "auth.login.success", metadata: ["userId": user.id])
    }

    func loginWithGoogle(idToken: String, accessToken: String?, nonce: String?) async throws {
        let user = try await AppTelemetry.shared.measure(operation: "auth.login_google") {
            try await supabaseAuth.loginWithGoogle(idToken: idToken, accessToken: accessToken, nonce: nonce)
        }

        await MainActor.run { self.updateAuthenticatedState(with: user) }

        await self.syncCarsFromBackend(userId: user.id, force: true)

        await MainActor.run {
            self.shouldPromptAddVehicle = false
        }
        AppTelemetry.shared.track(event: "auth.login_google.success", metadata: ["userId": user.id])
    }

    func loginWithApple(idToken: String, nonce: String, suggestedUsername: String?) async throws {
        let user = try await AppTelemetry.shared.measure(operation: "auth.login_apple") {
            try await supabaseAuth.loginWithApple(idToken: idToken, nonce: nonce, suggestedUsername: suggestedUsername)
        }

        await MainActor.run { self.updateAuthenticatedState(with: user) }

        await self.syncCarsFromBackend(userId: user.id, force: true)

        await MainActor.run {
            self.shouldPromptAddVehicle = false
        }
        AppTelemetry.shared.track(event: "auth.login_apple.success", metadata: ["userId": user.id])
    }

    func sendPasswordReset(email: String) async throws {
        try await AppTelemetry.shared.measure(operation: "auth.password_reset") {
            try await supabaseAuth.sendPasswordReset(email: email)
        }
        AppTelemetry.shared.track(event: "auth.password_reset.sent")
    }

    func handleIncomingURL(_ url: URL) async {
        do {
            let isRecovery = try await supabaseAuth.beginPasswordRecovery(from: url)
            if isRecovery {
                await MainActor.run {
                    self.isPresentingPasswordRecovery = true
                }
                AppTelemetry.shared.track(event: "auth.password_recovery.opened")
                return
            }

            if let user = try await supabaseAuth.completeAuthCallback(from: url) {
                await MainActor.run {
                    self.updateAuthenticatedState(with: user)
                    self.shouldPromptAddVehicle = false
                    self.isPresentingPasswordRecovery = false
                }
                await self.syncCarsFromBackend(userId: user.id, force: true)
                AppTelemetry.shared.track(event: "auth.callback.authenticated", metadata: ["userId": user.id])
            }
        } catch {
            AppTelemetry.shared.record(error: error, context: "auth.handle_incoming_url")
        }
    }

    private func observeAuthStateChanges() {
        authStateObserverTask?.cancel()
        authStateObserverTask = Task { [weak self] in
            for await (event, _) in SupabaseClientProvider.client.auth.authStateChanges {
                guard let self else { return }
                if event == .passwordRecovery {
                    await MainActor.run {
                        self.isPresentingPasswordRecovery = true
                    }
                }
            }
        }
    }

    func completePasswordReset(_ newPassword: String) async throws {
        try await AppTelemetry.shared.measure(operation: "auth.password_reset.complete") {
            try await supabaseAuth.completePasswordReset(newPassword: newPassword)
        }
        AppTelemetry.shared.track(event: "auth.password_reset.completed")
    }

    func dismissPasswordRecovery() {
        isPresentingPasswordRecovery = false
    }
    
    func register(email: String, password: String, username: String) async throws {
        let normalizedEmail = Self.normalizedSignupEmail(email)
        let user = try await AppTelemetry.shared.measure(operation: "auth.register") {
            try await supabaseAuth.register(email: normalizedEmail, password: password, username: username)
        }
        
        await MainActor.run { self.updateAuthenticatedState(with: user) }
        
        await self.syncCarsFromBackend(userId: user.id, force: true)
        AppTelemetry.shared.track(event: "auth.register.success", metadata: ["userId": user.id])
    }
    
    func logout() {
        print("[AuthVM] 🚪 logout() called: before state isAuthenticated=\(self.isAuthenticated), isLoading=\(self.isLoading), user=\(self.currentUser?.username ?? "nil")")
        
        Task {
            try? await supabaseAuth.logout()
        }
        AppTelemetry.shared.track(event: "auth.logout")
        
        print("[AuthVM] logout: clearing in-memory state")
        self.isLoading = false
        clearAuthenticatedState()
        print("[AuthVM] logout: posting empireRequestDismiss notification")
        NotificationCenter.default.post(name: .empireRequestDismiss, object: nil)
        print("[AuthVM] logout: invoking checkAuthStatus()")
        Task {
            await self.checkAuthStatus()
            print("[AuthVM] ✅ logout() finished: after state isAuthenticated=\(self.isAuthenticated), isLoading=\(self.isLoading)")
        }
    }
    
    func updateAvatar(withURL urlString: String) async {
        do {
            let updatedUser = try await supabaseAuth.updateAvatarPath(urlString)
            await MainActor.run {
                self.currentUser = updatedUser
                self.persistCurrentUser(updatedUser)
            }
        } catch {
            print("[AuthVM] ❌ Failed to update avatar path: \(error)")
            AppTelemetry.shared.record(error: error, context: "auth.update_avatar_path")
        }
    }

    func updateAvatar(imageData: Data) async throws {
        let updatedUser = try await AppTelemetry.shared.measure(operation: "auth.update_avatar") {
            try await supabaseAuth.uploadAvatar(imageData: imageData)
        }
        await MainActor.run {
            self.currentUser = updatedUser
            self.persistCurrentUser(updatedUser)
        }
        AppTelemetry.shared.track(event: "auth.update_avatar.success")
    }

    func updateUsername(_ username: String) async throws {
        let updatedUser = try await AppTelemetry.shared.measure(operation: "auth.update_username") {
            try await supabaseAuth.updateUsername(username)
        }
        await MainActor.run {
            self.currentUser = updatedUser
            self.persistCurrentUser(updatedUser)
        }
        AppTelemetry.shared.track(event: "auth.update_username.success")
    }

    func avatarPublicURLString(from avatarPath: String?) -> String? {
        guard let avatarPath, !avatarPath.isEmpty else { return nil }
        return SupabaseClientProvider
            .publicObjectURL(bucket: "avatars", path: avatarPath)?
            .absoluteString
    }
    
    func refreshCarsFromBackendIfAuthenticated() async {
        guard let userId = currentUser?.id, isAuthenticated else { return }
        await syncCarsFromBackend(userId: userId, force: true)
    }

    func completeOnboarding() {
        guard let userId = currentUser?.id else {
            isPresentingOnboarding = false
            return
        }
        UserDefaults.standard.set(true, forKey: onboardingKey(for: userId))
        isPresentingOnboarding = false
    }

    func replayOnboarding() {
        isPresentingOnboarding = true
    }

    private func scheduleCarsSync(userId: String, force: Bool) {
        syncCarsTask?.cancel()
        syncCarsTask = Task { [weak self] in
            await self?.syncCarsFromBackend(userId: userId, force: force)
        }
    }

    private func syncCarsFromBackend(userId: String, force: Bool) async {
        if !force,
           let lastCarsSyncAt,
           Date().timeIntervalSince(lastCarsSyncAt) < 20 {
            return
        }

        do {
            let cars = try await carsService.fetchCars(for: userId)
            if let context = self.modelContext {
                LocalStore.shared.replaceAllCars(cars, context: context, userKey: userId)
                lastCarsSyncAt = Date()
                print("[AuthVM] 🔄 Synced cars from Supabase and replaced local store: count=\(cars.count)")
                NotificationCenter.default.post(
                    name: .empireCarsDidSync,
                    object: nil,
                    userInfo: ["userId": userId, "count": cars.count]
                )
            } else {
                print("[AuthVM] ⚠️ ModelContext not set. Cannot sync cars to local store.")
            }
        } catch {
            print("[AuthVM] ❌ Failed to sync cars from Supabase: \(error)")
        }
    }
}

extension Notification.Name {
    static let empireRequestDismiss = Notification.Name("EmpireRequestDismiss")
    static let empireCarsDidSync = Notification.Name("EmpireCarsDidSync")
}
