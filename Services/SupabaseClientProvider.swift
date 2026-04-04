import Foundation
import OSLog
import Supabase

enum SupabaseClientProvider {
    private static let supportsImageTransformations = false
    private static let logger = Logger(subsystem: "com.empire.app", category: "supabase-config")

    enum ImageVariant {
        case avatar
        case thumbnail
        case grid
        case feed
        case detail

        fileprivate var width: Int {
            switch self {
            case .avatar:
                return 160
            case .thumbnail:
                return 160
            case .grid:
                return 640
            case .feed:
                return 1280
            case .detail:
                return 1800
            }
        }

        fileprivate var height: Int? {
            switch self {
            case .avatar, .thumbnail, .grid:
                return width
            case .feed, .detail:
                return nil
            }
        }

        fileprivate var quality: Int {
            switch self {
            case .avatar:
                return 70
            case .thumbnail:
                return 65
            case .grid:
                return 68
            case .feed:
                return 72
            case .detail:
                return 82
            }
        }
    }

    private static let fallbackProjectURL = URL(string: "https://matwihdeczmkdvsbuxvv.supabase.co")!
    private static let fallbackPublishableKey = "sb_publishable_Bd_9Istn0C4ep16Qg2M1RA_FCHJW4Bf"

    static let projectURL: URL = {
        if let environmentValue = debugEnvironmentValue(for: "SUPABASE_URL"),
           let environmentURL = validatedSupabaseURL(from: environmentValue) {
            return environmentURL
        }

        if let infoPlistValue = infoPlistValue(for: "SUPABASE_URL"),
           let infoPlistURL = validatedSupabaseURL(from: infoPlistValue) {
            return infoPlistURL
        }

        logger.error("Missing or invalid Supabase URL config. Falling back to bundled publishable project URL.")
        return fallbackProjectURL
    }()

    static let publishableKey: String = {
        guard let configuredKey = configValue(
            debugEnvironmentKey: "SUPABASE_ANON_KEY",
            infoPlistKey: "SUPABASE_ANON_KEY",
            invalidPlaceholders: ["YOUR_SUPABASE_ANON_KEY"]
        ) else {
            logger.error("Missing Supabase publishable key config. Falling back to bundled publishable key.")
            return fallbackPublishableKey
        }
        return configuredKey
    }()

    static let client: SupabaseClient = {
        let client = SupabaseClient(
            supabaseURL: projectURL,
            supabaseKey: publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storageKey: "empire-auth-token",
                    // Opt into Supabase's updated initial-session behavior so
                    // the bootstrap sequence is explicit and the SDK warning is silenced.
                    // AuthViewModel still validates expiry before authenticating a user.
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        return client
    }()
    static var shared: SupabaseClient { client }

    static func publicObjectURL(bucket: String, path: String) -> URL? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        let encodedPath = trimmedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { component in
                String(component).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(component)
            }
            .joined(separator: "/")

        return projectURL
            .appendingPathComponent("storage")
            .appendingPathComponent("v1")
            .appendingPathComponent("object")
            .appendingPathComponent("public")
            .appendingPathComponent(bucket)
            .appendingPathComponent(encodedPath)
    }

    static func transformedPublicObjectURL(bucket: String, path: String, variant: ImageVariant) -> URL? {
        guard supportsImageTransformations else {
            return publicObjectURL(bucket: bucket, path: path)
        }

        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        let encodedPath = trimmedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { component in
                String(component).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(component)
            }
            .joined(separator: "/")

        var components = URLComponents(
            url: projectURL
                .appendingPathComponent("storage")
                .appendingPathComponent("v1")
                .appendingPathComponent("render")
                .appendingPathComponent("image")
                .appendingPathComponent("public")
                .appendingPathComponent(bucket)
                .appendingPathComponent(encodedPath),
            resolvingAgainstBaseURL: false
        )

        var queryItems = [
            URLQueryItem(name: "width", value: String(variant.width)),
            URLQueryItem(name: "quality", value: String(variant.quality))
        ]
        if let height = variant.height {
            queryItems.append(URLQueryItem(name: "height", value: String(height)))
            queryItems.append(URLQueryItem(name: "resize", value: "cover"))
        }
        components?.queryItems = queryItems

        return components?.url ?? publicObjectURL(bucket: bucket, path: path)
    }

    private static func configValue(
        debugEnvironmentKey: String,
        infoPlistKey: String,
        invalidPlaceholders: [String]
    ) -> String? {
        if let environmentValue = debugEnvironmentValue(for: debugEnvironmentKey),
           isUsableConfigValue(environmentValue, invalidPlaceholders: invalidPlaceholders) {
            return environmentValue
        }

        if let infoPlistValue = infoPlistValue(for: infoPlistKey),
           isUsableConfigValue(infoPlistValue, invalidPlaceholders: invalidPlaceholders) {
            return infoPlistValue
        }

        return nil
    }

    private static func debugEnvironmentValue(for key: String) -> String? {
        #if DEBUG
        if let environmentValue = ProcessInfo.processInfo.environment[key] {
            let trimmedEnvironmentValue = environmentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedEnvironmentValue.isEmpty ? nil : trimmedEnvironmentValue
        }
        #endif

        return nil
    }

    private static func infoPlistValue(for key: String) -> String? {
        if let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmedInfoPlistValue = infoPlistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedInfoPlistValue.isEmpty ? nil : trimmedInfoPlistValue
        }

        return nil
    }

    private static func isUsableConfigValue(
        _ value: String,
        invalidPlaceholders: [String]
    ) -> Bool {
        guard !value.isEmpty else { return false }
        guard !invalidPlaceholders.contains(value) else { return false }
        guard !value.contains("$("), !value.contains("${") else { return false }
        return true
    }

    private static func validatedSupabaseURL(from rawValue: String) -> URL? {
        guard let components = URLComponents(string: rawValue) else { return nil }
        guard let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return nil
        }
        guard let host = components.host, !host.isEmpty else { return nil }
        return components.url
    }
}
