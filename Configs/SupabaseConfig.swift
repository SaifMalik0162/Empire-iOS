import Foundation

enum SupabaseConfig {
    private static let cachePrefix = "supabase.config."
    private static let bakedInURL = "https://matwihdeczmkdvsbuxvv.supabase.co"
    private static let bakedInPublishableKey = "sb_publishable_Bd_9Istn0C4ep16Qg2M1RA_FCHJW4Bf"

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
           isUsableValue(environmentValue) {
            cache(value: environmentValue, for: key)
            return environmentValue
        }

        for bundle in candidateBundles() {
            if let plistValue = bundle.object(forInfoDictionaryKey: key) as? String,
               isUsableValue(plistValue) {
                cache(value: plistValue, for: key)
                return plistValue
            }
        }

        if let cachedValue = UserDefaults.standard.string(forKey: cachePrefix + key),
           isUsableValue(cachedValue) {
            return cachedValue
        }

        if let bakedInValue = bakedInValue(for: key) {
            cache(value: bakedInValue, for: key)
            return bakedInValue
        }

        fatalError("Missing \(key). Set via Configs/Secrets.xcconfig (preferred) or Xcode Scheme environment variables.")
    }

    private static func cache(value: String, for key: String) {
        UserDefaults.standard.set(value, forKey: cachePrefix + key)
    }

    private static func bakedInValue(for key: String) -> String? {
        switch key {
        case "SUPABASE_URL":
            return bakedInURL
        case "SUPABASE_ANON_KEY":
            return bakedInPublishableKey
        default:
            return nil
        }
    }

    private static func candidateBundles() -> [Bundle] {
        var bundles: [Bundle] = [Bundle.main]
        bundles.append(contentsOf: Bundle.allBundles)
        bundles.append(contentsOf: Bundle.allFrameworks)

        var seen = Set<ObjectIdentifier>()
        return bundles.filter { bundle in
            seen.insert(ObjectIdentifier(bundle)).inserted
        }
    }

    private static func isUsableValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !trimmed.hasPrefix("YOUR_") else { return false }
        guard !trimmed.hasPrefix("REMOVED_") else { return false }
        guard !trimmed.contains("$(") else { return false }
        return true
    }
}
