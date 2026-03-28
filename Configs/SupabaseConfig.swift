import Foundation

enum SupabaseConfig {
    static let appURLScheme = "empireconnect"
    static let passwordResetRedirectURL = URL(string: "empireconnect://auth/reset-password")!
}
