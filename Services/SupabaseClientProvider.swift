import Foundation
import Supabase

enum SupabaseClientProvider {
    private static let supabaseURLString = "https://matwihdeczmkdvsbuxvv.supabase.co"
    private static let supabasePublishableKey = "sb_publishable_Bd_9Istn0C4ep16Qg2M1RA_FCHJW4Bf"

    static let projectURL = URL(string: supabaseURLString)!
    static let publishableKey = supabasePublishableKey

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
}
