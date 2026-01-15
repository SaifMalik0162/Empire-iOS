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
    @Published var shouldPromptAddVehicle:  Bool = false
    @Published var errorMessage: String?  = nil  // ✅ ADDED
    let instanceID = UUID()
    
    private let networkManager = NetworkManager.shared
    
    init() {
        print("[AuthVM] init:  instanceID=\(instanceID)")
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        print("[AuthVM] checkAuthStatus() start:  isLoading(before)=\(isLoading)")
        isLoading = true
        print("[AuthVM] checkAuthStatus() set isLoading=true")
        
        print("[AuthVM] checkAuthStatus() evaluating token presence...")
        if networkManager.isAuthenticated {
            print("[AuthVM] ✅ Found stored token, user is authenticated")
            isAuthenticated = true
            // TODO:  Optionally fetch user profile from backend
        } else {
            print("[AuthVM] ❌ No token found, user needs to log in")
            isAuthenticated = false
        }
        
        isLoading = false
        print("[AuthVM] checkAuthStatus() end: isAuthenticated=\(isAuthenticated), isLoading=\(isLoading)")
    }
    
    func login(email: String, password: String) async {
        print("[AuthVM] 🔐 login() called with email:  \(email)")
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.login(email: email, password: password)
            print("[AuthVM] 📡 Login response received:  success=\(response.success)")
            
            if response.success {
                self.currentUser = response.user
                self.isAuthenticated = true
                
                // ✅ SAVE USER ID
                if let user = response.user {
                    let userIdString = String(user.id)
                    UserDefaults.standard.set(userIdString, forKey: "currentUserId")
                    UserDefaults.standard.synchronize()
                    
                    let savedId = UserDefaults.standard.string(forKey: "currentUserId")
                    print("[AuthVM] ✅ User logged in: \(user.username)")
                    print("✅ Saved user ID: \(user.id)")
                    print("✅ Verified saved ID: \(savedId ??  "NOT SAVED!")")
                } else {
                    print("❌ No user in response!")
                    errorMessage = "Login failed:  No user data"
                }
            } else {
                print("❌ Login response success=false")
                errorMessage = response.message ?? "Login failed"
            }
            
            Task { @MainActor in
                self.shouldPromptAddVehicle = false
            }
        } catch {
            print("❌ Login error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func register(email: String, password: String, username: String) async {
        print("[AuthVM] 📝 register() called with email: \(email), username: \(username)")
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.register(
                email: email,
                password: password,
                username: username
            )
            print("[AuthVM] 📡 Register response received: success=\(response.success)")
            
            if response.success {
                self.currentUser = response.user
                self.isAuthenticated = true
                
                // ✅ SAVE USER ID
                if let user = response.user {
                    let userIdString = String(user.id)
                    UserDefaults.standard.set(userIdString, forKey: "currentUserId")
                    UserDefaults.standard.synchronize()
                    
                    let savedId = UserDefaults.standard.string(forKey: "currentUserId")
                    print("[AuthVM] ✅ User registered: \(user.username)")
                    print("✅ Saved user ID: \(user.id)")
                    print("✅ Verified saved ID: \(savedId ?? "NOT SAVED!")")
                } else {
                    print("❌ No user in response!")
                    errorMessage = "Registration failed: No user data"
                }
            } else {
                print("❌ Register response success=false")
                errorMessage = response.message ??  "Registration failed"
            }
        } catch {
            print("❌ Registration error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func logout() {
        print("[AuthVM] 🚪 logout() called:  before state isAuthenticated=\(self.isAuthenticated), isLoading=\(self.isLoading), user=\(self.currentUser?.username ?? "nil")")
        print("[AuthVM] logout:  calling APIService.shared.logout()")
        APIService.shared.logout()
        print("[AuthVM] logout: calling NetworkManager.shared.clearAuthToken()")
        NetworkManager.shared.clearAuthToken()
        
        // ✅ CLEAR USER ID
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        print("✅ Cleared user ID from UserDefaults")
        
        print("[AuthVM] logout: clearing in-memory state")
        self.currentUser = nil
        self.isAuthenticated = false
        self.shouldPromptAddVehicle = false
        self.isLoading = false
        self.errorMessage = nil
        print("[AuthVM] logout: posting empireRequestDismiss notification")
        NotificationCenter.default.post(name: .empireRequestDismiss, object: nil)
        print("[AuthVM] logout: invoking checkAuthStatus()")
        self.checkAuthStatus()
        print("[AuthVM] ✅ logout() finished:  after state isAuthenticated=\(self.isAuthenticated), isLoading=\(self.isLoading)")
    }
    
    func updateAvatar(withURL urlString: String) async {
        // TODO: Implement avatar update when APIService. updateAvatar is available
        await MainActor.run {
            print("⚠️ Skipping avatar update:  APIService.updateAvatar not implemented")
        }
    }
}

extension Notification.Name {
    static let empireRequestDismiss = Notification.Name("EmpireRequestDismiss")
}
