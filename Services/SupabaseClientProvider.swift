import Foundation
import Supabase

enum SupabaseClientProvider {
    private static let supabaseURLString = "https://matwihdeczmkdvsbuxvv.supabase.co"
    private static let supabasePublishableKey = "sb_publishable_Bd_9Istn0C4ep16Qg2M1RA_FCHJW4Bf"

    static let projectURL = URL(string: supabaseURLString)!
    static let publishableKey = supabasePublishableKey

    static let client: SupabaseClient = {
        // supabase-swift 2.41.1 force-unwraps `supabaseURL.host` during init,
        // so we hand it a known-good host-bearing URL instead of depending on
        // Info.plist/build-setting resolution in archived builds.
        let client = SupabaseClient(
            supabaseURL: projectURL,
            supabaseKey: publishableKey,
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
}
