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
            // TODO: Optionally fetch user profile from backend
        } else {
            print("[AuthVM] ❌ No token found, user needs to log in")
            isAuthenticated = false
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

