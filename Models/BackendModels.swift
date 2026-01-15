//
//  BackendModels. swift
//  Empire
//
//  Created by Vishwa Sivakumar on 2026-01-10.
//

import Foundation

// MARK: - Auth
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let username: String
}

struct AuthResponse: Codable {
    let success: Bool
    let token: String?
    let user: BackendUser?
    let message: String?
}

struct BackendUser:  Codable {
    let id: Int
    let email: String
    let username: String
}

// MARK: - Cars
struct BackendCar: Codable, Identifiable {
    let id: Int
    let userId: Int
    let make: String
    let model: String
    let year: Int
    let color: String?
    let imageUrl: String?
    let horsepower: Int?
    let stage: String?
    
    enum CodingKeys: String, CodingKey {
        case id, make, model, year, color, horsepower, stage
        case userId = "user_id"
        case imageUrl = "image_url"
    }
    
    var fullName: String {
        "\(year) \(make) \(model)"
    }
}

struct CarsResponse: Codable {
    let success: Bool
    let cars: [BackendCar]
}

struct CarCreateResponse: Codable {  // ← MAKE SURE THIS EXISTS
    let success: Bool
    let message: String
    let data: BackendCar
}

// MARK: - Meets
struct BackendMeet: Codable, Identifiable {
    let id: Int
    let title: String
    let location: String
    let meetDate: String
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, location, description
        case meetDate = "meet_date"
    }
}

struct MeetsResponse: Codable {
    let success: Bool
    let meets: [BackendMeet]
}

// MARK: - Health
struct HealthResponse: Codable {
    let success: Bool
    let message: String
}

struct ErrorResponse: Codable {
    let success: Bool
    let message: String
}
