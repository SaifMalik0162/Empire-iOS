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
    
    private let tokenKey = "authToken"
    
    var authToken: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }
    
    var isAuthenticated: Bool {
        authToken != nil
    }
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    func clearAuthToken() {
        self.authToken = nil
    }
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body:  Encodable? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Invalid response")
        }
        
        if APIConfig.enableNetworkLogging {
            print("📡 Status:  \(httpResponse.statusCode)")
            if let json = String(data: data, encoding: . utf8) {
                print("📄 Response: \(json)")
            }
        }
        
        let statusCode = httpResponse.statusCode
        
        // Handle different status codes
        if statusCode >= 200 && statusCode < 300 {
            // Success - decode response
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                return decoded
            } catch {
                throw NetworkError.decodingError(error)
            }
        } else if statusCode == 401 {
            // Unauthorized
            clearAuthToken()
            throw NetworkError.unauthorized
        } else {
            // Other errors
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Error: \(statusCode)")
        }
    }
}
