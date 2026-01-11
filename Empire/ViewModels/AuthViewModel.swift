//
//  AuthViewModel.swift
//  Empire
//
//  Created by Vishwa Sivakumar on 2026-01-10.
//

import Foundation
import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: BackendUser?
    @Published var isLoading = true
    
    private let networkManager = NetworkManager.shared
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        isLoading = true
        
        // Check if we have a token
        if networkManager.isAuthenticated {
            print("✅ Found stored token, user is authenticated")
            isAuthenticated = true
            // TODO: Optionally fetch user profile from backend
        } else {
            print("❌ No token found, user needs to log in")
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    func login(email: String, password: String) async throws {
        let response = try await APIService.shared.login(email: email, password: password)
        
        await MainActor.run {
            if response.success {
                self.currentUser = response.user
                self.isAuthenticated = true
                print("✅ User logged in:  \(response.user?.username ?? "unknown")")
            }
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
                print("✅ User registered: \(response.user?.username ?? "unknown")")
            }
        }
    }
    
    func logout() {
        APIService.shared.logout()
        currentUser = nil
        isAuthenticated = false
        print("✅ User logged out")
    }
}
