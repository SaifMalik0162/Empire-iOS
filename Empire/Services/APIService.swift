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

    private init() {
        // Register refresh handler so NetworkManager can call back to refresh tokens.
        networkManager.refreshHandler = { [unowned self] refreshToken in
            return try await self.performRefresh(refreshToken: refreshToken)
        }
    }

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
        let bodyData = try JSONEncoder().encode(request)
        let response:  AuthResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.login,
            method: .post,
            body: bodyData
        )

        if let token = response.token {
            // Store token(s) in the secure NetworkManager-backed Keychain.
            // If your backend returns a separate refresh token, update this to pass it here.
            NetworkManager.shared.setTokens(accessToken: token, refreshToken: token)
        }

        return response
    }

    func register(email: String, password: String, username: String) async throws -> AuthResponse {
        let request = RegisterRequest(email: email, password:  password, username: username)
        let bodyData = try JSONEncoder().encode(request)
        let response: AuthResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.register,
            method: .post,
            body: bodyData
        )

        if let token = response.token {
            NetworkManager.shared.setTokens(accessToken: token, refreshToken: token)
        }

        return response
    }

    func logout() {
        // Clear tokens from the secure store
        NetworkManager.shared.clearAuthToken()
    }

    // MARK: - Cars
    func getAllCars() async throws -> [BackendCar] {
        let response: CarsResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.cars
        )
        return response.cars
    }

    // MARK: - Token refresh
    /// Performs a refresh request against the backend and returns new tokens.
    private func performRefresh(refreshToken: String) async throws -> (accessToken: String, refreshToken: String) {
        struct RefreshRequest: Encodable {
            let refreshToken: String
        }

        struct RefreshResponse: Decodable {
            let accessToken: String?
            let refreshToken: String?
        }

        let urlString = APIConfig.baseURL + APIConfig.Endpoints.refresh
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var req = URLRequest(url: url, timeoutInterval: APIConfig.timeoutInterval)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = RefreshRequest(refreshToken: refreshToken)
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(RefreshResponse.self, from: data)
        guard let newAccess = decoded.accessToken, let newRefresh = decoded.refreshToken else {
            throw URLError(.cannotParseResponse)
        }

        return (accessToken: newAccess, refreshToken: newRefresh)
    }

    // MARK: - Meets
    func getAllMeets() async throws -> [BackendMeet] {
        let response: MeetsResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.meets
        )
        return response.meets
    }
}
