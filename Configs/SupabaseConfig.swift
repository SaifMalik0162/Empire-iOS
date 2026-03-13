import Foundation

enum SupabaseConfig {
    static let url = URL(string: "REMOVED_SUPABASE_URL")!

    static let anonKey = "REMOVED_SUPABASE_ANON_KEY"

    static let appURLScheme = "empireconnect"
    static let passwordResetRedirectURL = URL(string: "empireconnect://auth/reset-password")!
}
