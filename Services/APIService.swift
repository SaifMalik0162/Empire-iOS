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
    func login(email: String, password: String) async throws -> AuthResponse {
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
    
    func createCar(make: String, model: String, year: Int, color: String?, horsepower: Int?, stage: String?, userId: Int) async throws -> BackendCar {
        struct CreateCarRequest: Encodable {
            let make: String
            let model: String
            let year: Int
            let color: String?
            let horsepower: Int?
            let stage: String?
            let user_id: Int
        }
        
        let request = CreateCarRequest(
            make: make,
            model: model,
            year: year,
            color:  color,
            horsepower:  horsepower,
            stage:  stage,
            user_id:  userId
        )
        
        let response: CarCreateResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.cars,
            method: .post,
            body: request
        )
        
        return response.data
    }
    
    func updateCar(id: Int, make: String, model: String, year: Int, color: String?, horsepower: Int?, stage: String?) async throws -> BackendCar {
        struct UpdateCarRequest:  Encodable {
            let make: String
            let model: String
            let year: Int
            let color: String?
            let horsepower: Int?
            let stage: String?
        }
        
        let request = UpdateCarRequest(
            make:  make,
            model: model,
            year: year,
            color: color,
            horsepower: horsepower,
            stage: stage
        )
        
        let response: CarCreateResponse = try await networkManager.request(
            endpoint: "\(APIConfig.Endpoints.cars)/\(id)",
            method: .put,
            body: request,
            requiresAuth: true  // ← BACKEND REQUIRES AUTH
        )
        
        return response.data
    }
    
    func deleteCar(id: Int) async throws {
        struct DeleteResponse: Codable {
            let success: Bool
            let message: String
        }
        
        let _: DeleteResponse = try await networkManager.request(
            endpoint: "\(APIConfig.Endpoints.cars)/\(id)",
            method: .delete,
            requiresAuth: true  // ← BACKEND REQUIRES AUTH
        )
    }

    // MARK: - Meets
    func getAllMeets() async throws -> [BackendMeet] {
        let response: MeetsResponse = try await networkManager.request(
            endpoint: APIConfig.Endpoints.meets
        )
        return response.meets
    }
}
