import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case unknown(Error)
    
    var errorDescription: String?  {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case . decodingError(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Please log in again"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    
    // MARK: - Auth Token using KeychainService
    
    var authToken: String? {
        get { KeychainService.shared.readString(forKey: KeychainService.accessTokenKey) }
        set {
            if let token = newValue {
                _ = KeychainService.shared.saveString(token, forKey: KeychainService.accessTokenKey)
            } else {
                _ = KeychainService.shared.delete(forKey: KeychainService.accessTokenKey)
            }
        }
    }
    
    // MARK: - Refresh Token support via KeychainService
    
    private var refreshToken: String? {
        get { KeychainService.shared.readString(forKey: KeychainService.refreshTokenKey) }
        set {
            if let v = newValue {
                _ = KeychainService.shared.saveString(v, forKey: KeychainService.refreshTokenKey)
            } else {
                _ = KeychainService.shared.delete(forKey: KeychainService.refreshTokenKey)
            }
        }
    }
    
    var isAuthenticated: Bool {
        let token = authToken
        if APIConfig.enableNetworkLogging {
            print("[Network] isAuthenticated? token=\(token != nil ? "present" : "nil")")
        }
        return token != nil
    }
    
    func setAuthToken(_ token: String) {
        _ = KeychainService.shared.saveString(token, forKey: KeychainService.accessTokenKey)
    }
    
    func clearAuthToken() {
        if APIConfig.enableNetworkLogging {
            let old = authToken ?? "nil"
            print("[Network] clearAuthToken old=\(old)")
        }
        _ = KeychainService.shared.delete(forKey: KeychainService.accessTokenKey)
        _ = KeychainService.shared.delete(forKey: KeychainService.refreshTokenKey)
        if APIConfig.enableNetworkLogging {
            print("[Network] clearAuthToken new=\(authToken ?? "nil")")
        }
    }
    
    // MARK: - Refresh Auth Token if needed
    
    private struct RefreshRequest: Encodable {
        let refreshToken: String
    }
    private struct RefreshResponse: Decodable {
        let token: String
        let refreshToken: String?
    }
    
    func refreshAuthTokenIfNeeded() async throws {
        guard let rt = refreshToken else {
            if APIConfig.enableNetworkLogging {
                print("[Network] No refresh token available, cannot refresh")
            }
            throw NetworkError.unauthorized
        }
        
        if APIConfig.enableNetworkLogging {
            print("[Network] Attempting to refresh auth token")
        }
        
        let refreshRequest = RefreshRequest(refreshToken: rt)
        
        do {
            let refreshResponse: RefreshResponse = try await _request(
                endpoint: "/auth/refresh",
                method: .post,
                body: refreshRequest,
                requiresAuth: false,
                didRetry: true // no retry inside refresh
            )
            if APIConfig.enableNetworkLogging {
                print("[Network] Token refreshed successfully")
            }
            self.authToken = refreshResponse.token
            if let newRefreshToken = refreshResponse.refreshToken {
                self.refreshToken = newRefreshToken
            }
        } catch {
            if APIConfig.enableNetworkLogging {
                print("[Network] Failed to refresh token: \(error.localizedDescription)")
            }
            clearAuthToken()
            throw NetworkError.unauthorized
        }
    }
    
    // MARK: - Requests
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body:  Encodable? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        return try await _request(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth, didRetry: false)
    }
    
    private func _request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = false,
        didRetry: Bool
    ) async throws -> T {
        let telemetryOperation = "network.request.\(method.rawValue.lowercased())"
        return try await AppTelemetry.shared.measure(operation: telemetryOperation) {
        
            guard let url = URL(string: APIConfig.baseURL + endpoint) else {
                throw NetworkError.invalidURL
            }
        
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            request.timeoutInterval = APIConfig.timeoutInterval
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
            if requiresAuth, let token = authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        
            if let body = body {
                request.httpBody = try JSONEncoder().encode(body)
            }
        
            if APIConfig.enableNetworkLogging {
                print("🌐 \(method.rawValue) \(url)")
            }
            AppTelemetry.shared.track(event: "network.request.started", metadata: ["method": method.rawValue, "endpoint": endpoint])
        
            let (data, response) = try await URLSession.shared.data(for: request)
        
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.serverError("Invalid response")
            }
        
            if APIConfig.enableNetworkLogging {
                print("📡 Status:  \(httpResponse.statusCode)")
                if let json = String(data: data, encoding: .utf8) {
                    print("📄 Response: \(json)")
                }
            }
            AppTelemetry.shared.track(event: "network.request.finished", metadata: ["statusCode": String(httpResponse.statusCode), "endpoint": endpoint])
        
            let statusCode = httpResponse.statusCode
        
            if statusCode >= 200 && statusCode < 300 {
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    return decoded
                } catch {
                    throw NetworkError.decodingError(error)
                }
            } else if statusCode == 401 {
                if didRetry {
                    clearAuthToken()
                    throw NetworkError.unauthorized
                } else {
                    do {
                        try await refreshAuthTokenIfNeeded()
                        return try await _request(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth, didRetry: true)
                    } catch {
                        clearAuthToken()
                        throw NetworkError.unauthorized
                    }
                }
            } else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.serverError(errorResponse.message)
                }
                throw NetworkError.serverError("Error: \(statusCode)")
            }
        }
    }
    
    func uploadMultipart<T: Decodable>(
        endpoint: String,
        imageData: Data,
        imageFieldName: String = "image",
        fileName: String = "upload.jpg",
        mimeType: String = "image/jpeg",
        additionalFields: [String: String] = [:],
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.timeoutInterval = APIConfig.timeoutInterval

        // Boundary
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Build body
        var body = Data()
        func append(_ string: String) {
            if let data = string.data(using: .utf8) { body.append(data) }
        }

        // Additional fields
        for (key, value) in additionalFields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        // Image part
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(imageFieldName)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        append("\r\n")

        // Closing boundary
        append("--\(boundary)--\r\n")

        request.httpBody = body

        if APIConfig.enableNetworkLogging {
            print("🌐 UPLOAD POST \(url) (multipart)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Invalid response")
        }

        if APIConfig.enableNetworkLogging {
            print("📡 Status:  \(httpResponse.statusCode)")
            if let json = String(data: data, encoding: .utf8) {
                print("📄 Response: \(json)")
            }
        }

        let statusCode = httpResponse.statusCode
        if statusCode >= 200 && statusCode < 300 {
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                return decoded
            } catch {
                throw NetworkError.decodingError(error)
            }
        } else if statusCode == 401 {
            clearAuthToken()
            throw NetworkError.unauthorized
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Error: \(statusCode)")
        }
    }
}

