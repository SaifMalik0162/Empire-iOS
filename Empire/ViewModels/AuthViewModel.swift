//
//  AuthViewModel.swift
//  Empire
//
//  Created by Vishwa Sivakumar on 2026-01-10.
//

import Foundation
import SwiftUI
import Combine

@MainActor class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: BackendUser?
    @Published var isLoading = true
    @Published var shouldPromptAddVehicle: Bool = false
    let instanceID = UUID()
    
    private let networkManager = NetworkManager.shared
    
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
    
    init() {
        print("[AuthVM] init: instanceID=\(instanceID)")
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        print("[AuthVM] checkAuthStatus() start: isLoading(before)=\(isLoading)")
        isLoading = true
        print("[AuthVM] checkAuthStatus() set isLoading=true")

        print("[AuthVM] checkAuthStatus() evaluating token presence...")
        if networkManager.isAuthenticated {
            print("[AuthVM] ✅ Found stored token, user is authenticated")
            isAuthenticated = true

            // Try to restore a previously persisted user first
            if let restored = restoreCurrentUser() {
                self.currentUser = restored
                UserDefaults.standard.set(restored.id, forKey: "currentUserId")
                print("[AuthVM] Restored user from disk: \(restored.username)")
                // TODO: When APIService exposes a current-user endpoint, refresh profile here.
            }
        } else {
            print("[AuthVM] ❌ No token found, user needs to log in")
            isAuthenticated = false
            self.currentUser = nil
            self.persistCurrentUser(nil)
            UserDefaults.standard.removeObject(forKey: "currentUserId")
        }

        isLoading = false
        print("[AuthVM] checkAuthStatus() end: isAuthenticated=\(isAuthenticated), isLoading=\(isLoading)")
    }
    
    func login(email: String, password: String) async throws {
        let response = try await APIService.shared.login(email: email, password: password)
        
        await MainActor.run {
            if response.success {
                self.currentUser = response.user
                self.isAuthenticated = true
                if let user = response.user {
                    UserDefaults.standard.set(user.id, forKey: "currentUserId")
                    self.persistCurrentUser(user)
                }
                print("[AuthVM] ✅ User logged in:  \(response.user?.username ?? "unknown")")
            }
        }
        
        Task { @MainActor in
            // TODO: Implement vehicle check when APIService.getMyVehicles is available
            self.shouldPromptAddVehicle = false
        }
    }
    
    func register(email: String, password: String, username: String) async throws {
        let response = try await APIService.shared.register(
            email: email,
            password: password,
            username: username
        )
        
        await MainActor.run {
            if response.success {
                self.currentUser = response.user
                self.isAuthenticated = true
                if let user = response.user {
                    UserDefaults.standard.set(user.id, forKey: "currentUserId")
                    self.persistCurrentUser(user)
                }
                print("[AuthVM] ✅ User registered: \(response.user?.username ?? "unknown")")
            }
        }
    }
    
    func logout() {
        print("[AuthVM] 🚪 logout() called: before state isAuthenticated=\(self.isAuthenticated), isLoading=\(self.isLoading), user=\(self.currentUser?.username ?? "nil")")
        print("[AuthVM] logout: calling APIService.shared.logout()")
        APIService.shared.logout()
        print("[AuthVM] logout: calling NetworkManager.shared.clearAuthToken()")
        NetworkManager.shared.clearAuthToken()
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
        self.checkAuthStatus()
        print("[AuthVM] ✅ logout() finished: after state isAuthenticated=\(self.isAuthenticated), isLoading=\(self.isLoading)")
    }
    
    func updateAvatar(withURL urlString: String) async {
        // TODO: Implement avatar update when APIService.updateAvatar is available
        await MainActor.run {
            print("⚠️ Skipping avatar update: APIService.updateAvatar not implemented")
        }
    }
}

extension Notification.Name {
    static let empireRequestDismiss = Notification.Name("EmpireRequestDismiss")
}
