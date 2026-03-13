import Foundation

enum SupabaseConfig {
    static let url: URL = {
        let rawValue = requiredValue(for: "SUPABASE_URL")
        guard let parsedURL = URL(string: rawValue) else {
            fatalError("Invalid SUPABASE_URL value. Expected a valid URL string.")
        }
        return parsedURL
    }()

    static let publishableKey: String = requiredValue(for: "SUPABASE_ANON_KEY")

    static let appURLScheme = "empireconnect"
    static let passwordResetRedirectURL = URL(string: "empireconnect://auth/reset-password")!

    private static func requiredValue(for key: String) -> String {
        if let environmentValue = ProcessInfo.processInfo.environment[key],
           !environmentValue.isEmpty,
           !environmentValue.hasPrefix("YOUR_"),
           !environmentValue.hasPrefix("REMOVED_") {
            return environmentValue
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !plistValue.isEmpty,
           !plistValue.hasPrefix("YOUR_"),
           !plistValue.hasPrefix("REMOVED_") {
            return plistValue
        }

        fatalError("Missing \(key). Set it via Xcode Scheme environment variables or Info.plist local overrides.")
    }
}
