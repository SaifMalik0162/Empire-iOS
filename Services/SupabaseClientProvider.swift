import Foundation
import Supabase

enum SupabaseClientProvider {
    private static let supabaseURLString = "https://matwihdeczmkdvsbuxvv.supabase.co"
    private static let supabasePublishableKey = "sb_publishable_Bd_9Istn0C4ep16Qg2M1RA_FCHJW4Bf"

    static let client: SupabaseClient = {
        // supabase-swift 2.41.1 force-unwraps `supabaseURL.host` during init,
        // so we hand it a known-good host-bearing URL instead of depending on
        // Info.plist/build-setting resolution in archived builds.
        let supabaseURL = URL(string: supabaseURLString)!
        let client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabasePublishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storageKey: "empire-auth-token",
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        return client
    }()
    static var shared: SupabaseClient { client }
}
