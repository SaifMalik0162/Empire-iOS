import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    case unauthorized
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

final class NetworkManager {
    static let shared = NetworkManager()
    
    private(set) var authToken: String?
    
    private init() {
        loadAuthToken()
    }
    
    // MARK: - Auth Token Management
    
    func setAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "authToken")
    }
    
    func clearAuthToken() {
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "authToken")
    }
    
    private func loadAuthToken() {
        self.authToken = UserDefaults.standard.string(forKey: "authToken")
    }
    
    var isAuthenticated: Bool {
        if APIConfig.enableNetworkLogging {
            print("[Network] isAuthenticated?  token=\(authToken != nil ? "exists" : "nil")")
        }
        return authToken != nil
    }
    
    // MARK: - Generic Request
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body:  Encodable? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url:  url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = APIConfig.timeoutInterval
        
        // Add auth token if required
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body if provided
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
            
            if APIConfig.enableNetworkLogging {
                if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                    print("📤 Request Body: \(jsonString)")
                }
            }
        }
        
        if APIConfig.enableNetworkLogging {
            print("🌐 \(method.rawValue) \(url)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Invalid response")
        }
        
        if APIConfig.enableNetworkLogging {
            print("📡 Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: . utf8) {
                print("📄 Response: \(jsonString)")
            }
        }
        
        let statusCode = httpResponse.statusCode
        
        if statusCode >= 200 && statusCode < 300 {
            // Success - decode response
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                return decoded
            } catch {
                if APIConfig.enableNetworkLogging {
                    print("❌ DECODING ERROR:")
                    print("   Type: \(T.self)")
                    print("   Error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("   Raw JSON: \(jsonString)")
                    }
                }
                throw NetworkError.decodingError(error)
            }
        } else if statusCode == 401 {
            // Unauthorized - clear token
            clearAuthToken()
            throw NetworkError.unauthorized
        } else {
            // Server error
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("HTTP Error: \(statusCode)")
        }
    }
    
    // MARK: - Image Upload
    
    func uploadImage<T: Decodable>(
        endpoint: String,
        imageData: Data,
        fieldName: String = "image",
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = APIConfig.timeoutInterval
        
        // Create boundary for multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Build multipart body
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"car-image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        if APIConfig.enableNetworkLogging {
            print("🌐 POST \(url) (image upload, \(imageData.count) bytes)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Invalid response")
        }
        
        if APIConfig.enableNetworkLogging {
            print("📡 Status: \(httpResponse.statusCode)")
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
                if APIConfig.enableNetworkLogging {
                    print("❌ DECODING ERROR:")
                    print("   Type: \(T.self)")
                    print("   Error: \(error)")
                }
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
