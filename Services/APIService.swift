//
//  APIService.swift
//  Empire
//
//  Created by Vishwa Sivakumar on 2026-01-10.
//

import Foundation

class APIService {
    static let shared = APIService()
    private let networkManager = NetworkManager.shared
    private init() {}

    // MARK: - Health
    func healthCheck() async throws -> Bool {
        let response:  HealthResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.health
        )
        return response.success
    }

    // MARK: - Auth
    func login(email:  String, password: String) async throws -> AuthResponse {
        let request = LoginRequest(email: email, password: password)
        let response:  AuthResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.login,
            method: .post,
            body: request
        )

        if let token = response.token {
            networkManager.setAuthToken(token)
        }

        return response
    }

    func register(email: String, password: String, username: String) async throws -> AuthResponse {
        let request = RegisterRequest(email: email, password:  password, username: username)
        let response: AuthResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.register,
            method: .post,
            body: request
        )

        if let token = response.token {
            networkManager.setAuthToken(token)
        }

        return response
    }

    func logout() {
        networkManager.clearAuthToken()
    }

    // MARK: - Cars
    func getAllCars() async throws -> [BackendCar] {
        let response: CarsResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.cars
        )
        return response.cars
    }

    // MARK: - Meets
    func getAllMeets() async throws -> [BackendMeet] {
        let response: MeetsResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.meets
        )
        return response.meets
    }
}
