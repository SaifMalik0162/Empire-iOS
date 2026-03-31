import Foundation

enum SupabaseConfig {
    static let appURLScheme = "empireconnect"
    static let oauthRedirectURL = URL(string: "empireconnect://auth/callback")!
    static let passwordResetRedirectURL = URL(string: "empireconnect://auth/reset-password")!

    static let googleClientID = requiredConfigValue(
        debugEnvironmentKey: "GOOGLE_IOS_CLIENT_ID",
        infoPlistKey: "GIDClientID"
    )

    static let googleServerClientID = requiredConfigValue(
        debugEnvironmentKey: "GOOGLE_WEB_CLIENT_ID",
        infoPlistKey: "GIDServerClientID"
    )

    static let googleReversedClientIDScheme = requiredConfigValue(
        debugEnvironmentKey: "GOOGLE_REVERSED_CLIENT_ID_SCHEME",
        infoPlistKey: nil
    )

    private static func requiredConfigValue(
        debugEnvironmentKey: String,
        infoPlistKey: String?
    ) -> String {
        #if DEBUG
        if let environmentValue = ProcessInfo.processInfo.environment[debugEnvironmentKey],
           let sanitizedEnvironmentValue = sanitizedConfigValue(environmentValue) {
            return sanitizedEnvironmentValue
        }
        #endif

        if let infoPlistKey,
           let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String,
           let sanitizedInfoPlistValue = sanitizedConfigValue(infoPlistValue) {
            return sanitizedInfoPlistValue
        }

        preconditionFailure("Missing required Google auth config for \(debugEnvironmentKey). Verify AppConfig.xcconfig and Info.plist URL scheme substitution.")
    }

    private static func sanitizedConfigValue(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }
        guard !trimmedValue.contains("$("), !trimmedValue.contains("${") else { return nil }
        return trimmedValue
    }
}
