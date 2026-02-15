import Foundation

actor TokenRefresher {
    private var currentTask: Task<(String, String)?, Never>? = nil

    func perform(using handler: @escaping (String) async throws -> (accessToken: String, refreshToken: String), refreshToken: String) async -> (String, String)? {
        if let t = currentTask {
            return await t.value
        }

        currentTask = Task { () -> (String, String)? in
            do {
                let result = try await handler(refreshToken)
                return (result.accessToken, result.refreshToken)
            } catch {
                return nil
            }
        }

        let result = await currentTask!.value
        currentTask = nil
        return result
    }
}

final class NetworkManager {
    static let shared = NetworkManager()

    private let keychain = KeychainService.shared
    private let accessTokenKey = "com.empire.accessToken"
    private let refreshTokenKey = "com.empire.refreshToken"

    private let refresher = TokenRefresher()

    /// Optional async handler that, given the current refresh token, returns new tokens.
    /// APIService (or other network layer) can set this to perform the actual network refresh.
    var refreshHandler: ((String) async throws -> (accessToken: String, refreshToken: String))?

    private init() {}

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    /// Generic request helper. Encoded `body` should be JSON `Data` when provided.
    func request<T: Decodable>(endpoint: String, method: HTTPMethod = .get, body: Data? = nil) async throws -> T {
        let urlString = APIConfig.baseURL + endpoint
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var req = URLRequest(url: url, timeoutInterval: APIConfig.timeoutInterval)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if APIConfig.enableNetworkLogging {
            print("[Network] Request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if APIConfig.enableNetworkLogging {
            print("[Network] Response: \(http.statusCode) - \(String(data: data, encoding: .utf8) ?? "<binary>")")
        }

        if http.statusCode == 401 {
            // If this was a refresh endpoint, don't attempt refresh again.
            if endpoint == APIConfig.Endpoints.refresh {
                throw URLError(.userAuthenticationRequired)
            }

            // Try to refresh tokens and retry once.
            let refreshed = await refreshTokenIfNeeded()
            if refreshed {
                // Retry request with new token
                var retryReq = req
                if let token = accessToken {
                    retryReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                let (retryData, retryResp) = try await URLSession.shared.data(for: retryReq)
                guard let retryHttp = retryResp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                guard (200...299).contains(retryHttp.statusCode) else { throw URLError(.badServerResponse) }
                return try JSONDecoder().decode(T.self, from: retryData)
            }

            throw URLError(.userAuthenticationRequired)
        }

        guard (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    var accessToken: String? {
        keychain.readString(forKey: accessTokenKey)
    }

    var refreshToken: String? {
        keychain.readString(forKey: refreshTokenKey)
    }

    var isAuthenticated: Bool {
        guard let token = accessToken, !token.isEmpty else { return false }
        return true
    }

    func setTokens(accessToken: String, refreshToken: String) {
        _ = keychain.saveString(accessToken, forKey: accessTokenKey)
        _ = keychain.saveString(refreshToken, forKey: refreshTokenKey)
    }

    func clearAuthToken() {
        _ = keychain.delete(forKey: accessTokenKey)
        _ = keychain.delete(forKey: refreshTokenKey)
    }

    /// Attempts a single-flight refresh using `refreshHandler` if available.
    /// Returns true if refresh succeeded and tokens were stored, false otherwise.
    func refreshTokenIfNeeded() async -> Bool {
        guard let currentRefresh = refreshToken, let handler = refreshHandler else {
            return false
        }

        if let result = await refresher.perform(using: handler, refreshToken: currentRefresh) {
            setTokens(accessToken: result.0, refreshToken: result.1)
            return true
        }

        return false
    }
}
