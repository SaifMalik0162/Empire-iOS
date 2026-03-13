import Foundation
import Supabase

enum SupabaseClientProvider {
    static let client: SupabaseClient = {
        let client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
        return client
    }()
    static var shared: SupabaseClient { client }
}
