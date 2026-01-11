//
//  APIConfig.swift
//  Empire
//
//  Created by Vishwa Sivakumar on 2026-01-10.
//

import Foundation

enum APIConfig {
    #if DEBUG
    static let isDebug = true
    #else
    static let isDebug = false
    #endif
    
    private static let developmentURL = "http://localhost:3000/api"
    private static let productionURL = "https://empire-backend-qouf.onrender.com/api"
    
    static var baseURL: String {
        return productionURL // Use production for now
    }
    
    enum Endpoints {
        static let health = "/health"
        static let login = "/auth/login"
        static let register = "/auth/register"
        static let cars = "/cars"
        static let meets = "/meets"
    }
    
    static let timeoutInterval: TimeInterval = 30.0
    static let enableNetworkLogging = isDebug
}
