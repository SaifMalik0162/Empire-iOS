import Foundation
import SwiftUI
import Combine
import Supabase
import SwiftData

@MainActor class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: BackendUser?
    @Published var isLoading = true
    @Published var shouldPromptAddVehicle: Bool = false
    let instanceID = UUID()
    
    private let networkManager = NetworkManager.shared
    private let supabaseAuth = SupabaseAuthService()
    private let carsService = SupabaseCarsService()
    
    private var modelContext: ModelContext? = nil
    
    private let userDefaultsUserKey = "currentUser"

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
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        if isAuthenticated, let userId = currentUser?.id {
            syncCarsAfterAuth(userId: userId)
        }
    }
    
    init() {
        print("[AuthVM] init: instanceID=\(instanceID)")
        Task {
            await checkAuthStatus()
        }
    }
    
    func checkAuthStatus() async {
        print("[AuthVM] checkAuthStatus() start: isLoading(before)=\(isLoading)")
        isLoading = true
        print("[AuthVM] checkAuthStatus() set isLoading=true")

        do {
            if let session = try await supabaseAuth.currentSession(), !session.isExpired, let backendUser = try await supabaseAuth.currentUser() {
                isAuthenticated = true
                self.currentUser = backendUser
                UserDefaults.standard.set(backendUser.id, forKey: "currentUserId")
                self.persistCurrentUser(backendUser)
                self.syncCarsAfterAuth(userId: backendUser.id)
            } else {
                isAuthenticated = false
                self.currentUser = nil
                self.persistCurrentUser(nil)
                UserDefaults.standard.removeObject(forKey: "currentUserId")
            }
        } catch {
            isAuthenticated = false
            self.currentUser = nil
            self.persistCurrentUser(nil)
            UserDefaults.standard.removeObject(forKey: "currentUserId")
        }

        isLoading = false
        print("[AuthVM] checkAuthStatus() end: isAuthenticated=\(isAuthenticated), isLoading=\(isLoading)")
    }
    
    func login(email: String, password: String) async throws {
        let user = try await supabaseAuth.login(email: email, password: password)
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            UserDefaults.standard.set(user.id, forKey: "currentUserId")
            self.persistCurrentUser(user)
        }
        
        self.syncCarsAfterAuth(userId: user.id)
        
        await MainActor.run {
            self.shouldPromptAddVehicle = false
        }
    }

    func loginWithApple(idToken: String, nonce: String, suggestedUsername: String?) async throws {
        let user = try await supabaseAuth.loginWithApple(idToken: idToken, nonce: nonce, suggestedUsername: suggestedUsername)

        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            UserDefaults.standard.set(user.id, forKey: "currentUserId")
            self.persistCurrentUser(user)
        }

        self.syncCarsAfterAuth(userId: user.id)

        await MainActor.run {
            self.shouldPromptAddVehicle = false
        }
    }

    func sendPasswordReset(email: String) async throws {
        try await supabaseAuth.sendPasswordReset(email: email)
    }
    
    func register(email: String, password: String, username: String) async throws {
        let user = try await supabaseAuth.register(email: email, password: password, username: username)
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            UserDefaults.standard.set(user.id, forKey: "currentUserId")
            self.persistCurrentUser(user)
        }
        
        self.syncCarsAfterAuth(userId: user.id)
    }
    
    func logout() {
        print("[AuthVM] 🚪 logout() called: before state isAuthenticated=\(self.isAuthenticated), isLoading=\(self.isLoading), user=\(self.currentUser?.username ?? "nil")")
        
        Task {
            try? await supabaseAuth.logout()
        }
        
        print("[AuthVM] logout: clearing in-memory state")
        self.currentUser = nil
        self.isAuthenticated = false
        self.shouldPromptAddVehicle = false
        self.isLoading = false
        self.persistCurrentUser(nil)
        UserDefaults.standard.removeObject(forKey: "currentUserId")
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
        }
    }

    func updateAvatar(imageData: Data) async throws {
        let updatedUser = try await supabaseAuth.uploadAvatar(imageData: imageData)
        await MainActor.run {
            self.currentUser = updatedUser
            self.persistCurrentUser(updatedUser)
        }
    }

    func updateUsername(_ username: String) async throws {
        let updatedUser = try await supabaseAuth.updateUsername(username)
        await MainActor.run {
            self.currentUser = updatedUser
            self.persistCurrentUser(updatedUser)
        }
    }

    func avatarPublicURLString(from avatarPath: String?) -> String? {
        guard let avatarPath, !avatarPath.isEmpty else { return nil }
        let base = SupabaseConfig.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encodedPath = avatarPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? avatarPath
        return "\(base)/storage/v1/object/public/avatars/\(encodedPath)"
    }
    
    private func syncCarsAfterAuth(userId: String) {
        Task {
            do {
                let cars = try await carsService.fetchCars(for: userId)
                if let context = self.modelContext {
                    LocalStore.shared.replaceAllCars(cars, context: context, userKey: userId)
                    print("[AuthVM] 🔄 Synced cars from Supabase and replaced local store: count=\(cars.count)")
                } else {
                    print("[AuthVM] ⚠️ ModelContext not set. Cannot sync cars to local store.")
                }
            } catch {
                print("[AuthVM] ❌ Failed to sync cars from Supabase: \(error)")
            }
        }
    }
}

extension Notification.Name {
    static let empireRequestDismiss = Notification.Name("EmpireRequestDismiss")
}
