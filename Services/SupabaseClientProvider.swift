import Foundation
import Supabase

enum SupabaseClientProvider {
    private static let fallbackProjectURL = URL(string: "https://matwihdeczmkdvsbuxvv.supabase.co")!
    private static let fallbackPublishableKey = "sb_publishable_Bd_9Istn0C4ep16Qg2M1RA_FCHJW4Bf"

    static let projectURL: URL = {
        guard let rawValue = configValue(
            debugEnvironmentKey: "SUPABASE_URL",
            infoPlistKey: "SUPABASE_URL",
            invalidPlaceholders: ["YOUR_SUPABASE_URL"]
        ) else {
            assertionFailure("Missing Supabase URL config. Falling back to bundled publishable project URL.")
            return fallbackProjectURL
        }

        guard let url = validatedSupabaseURL(from: rawValue) else {
            assertionFailure("Invalid Supabase URL configured in SUPABASE_URL: \(rawValue). Falling back to bundled publishable project URL.")
            return fallbackProjectURL
        }
        return url
    }()

    static let publishableKey: String = {
        guard let configuredKey = configValue(
            debugEnvironmentKey: "SUPABASE_ANON_KEY",
            infoPlistKey: "SUPABASE_ANON_KEY",
            invalidPlaceholders: ["YOUR_SUPABASE_ANON_KEY"]
        ) else {
            assertionFailure("Missing Supabase publishable key config. Falling back to bundled publishable key.")
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

    private static func configValue(
        debugEnvironmentKey: String,
        infoPlistKey: String,
        invalidPlaceholders: [String]
    ) -> String? {
        #if DEBUG
        if let environmentValue = ProcessInfo.processInfo.environment[debugEnvironmentKey] {
            let trimmedEnvironmentValue = environmentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if isUsableConfigValue(trimmedEnvironmentValue, invalidPlaceholders: invalidPlaceholders) {
                return trimmedEnvironmentValue
            }
        }
        #endif

        if let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String {
            let trimmedInfoPlistValue = infoPlistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if isUsableConfigValue(trimmedInfoPlistValue, invalidPlaceholders: invalidPlaceholders) {
                return trimmedInfoPlistValue
            }
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
