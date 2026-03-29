import Foundation

enum SupabaseConfig {
    static let appURLScheme = "empireconnect"
    static let oauthRedirectURL = URL(string: "empireconnect://auth/callback")!
    static let passwordResetRedirectURL = URL(string: "empireconnect://auth/reset-password")!
    private static let fallbackGoogleClientID = "404305150-p4m9htb664lb1439rd4oioru7qvg6b62.apps.googleusercontent.com"
    private static let fallbackGoogleServerClientID = "404305150-j93e29ijdfvnnk134v2ih0bk1frcsf58.apps.googleusercontent.com"
    private static let fallbackGoogleReversedClientIDScheme = "com.googleusercontent.apps.404305150-p4m9htb664lb1439rd4oioru7qvg6b62"

    static let googleClientID = configValue(
        debugEnvironmentKey: "GOOGLE_IOS_CLIENT_ID",
        infoPlistKey: "GIDClientID",
        fallback: fallbackGoogleClientID
    )

    static let googleServerClientID = configValue(
        debugEnvironmentKey: "GOOGLE_WEB_CLIENT_ID",
        infoPlistKey: "GIDServerClientID",
        fallback: fallbackGoogleServerClientID
    )

    static let googleReversedClientIDScheme = configValue(
        debugEnvironmentKey: "GOOGLE_REVERSED_CLIENT_ID_SCHEME",
        infoPlistKey: nil,
        fallback: fallbackGoogleReversedClientIDScheme
    )

    private static func configValue(
        debugEnvironmentKey: String,
        infoPlistKey: String?,
        fallback: String
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

        return fallback
    }

    private static func sanitizedConfigValue(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }
        guard !trimmedValue.contains("$("), !trimmedValue.contains("${") else { return nil }
        return trimmedValue
    }
}
