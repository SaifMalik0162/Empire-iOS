import Foundation
import Supabase
import OSLog

struct BackendUser: Codable, Equatable {
    let id: String
    let username: String
    let email: String
}

private struct SBProfileRow: Codable {
    let id: String
    let username: String?
}

@MainActor
final class SupabaseAuthService {
    private let client = SupabaseClientProvider.client
    private let logger = AppLogger.supabaseAuth

    // MARK: - Sign Up / Register
    func register(email: String, password: String, username: String) async throws -> BackendUser {
        let response = try await client.auth.signUp(email: email, password: password)
        let user = response.user
        do {
            _ = try await client
                .from("profiles")
                .upsert([
                    "id": user.id.uuidString,
                    "username": username
                ], onConflict: "id")
                .execute()
        } catch {
            logger.warning("Profile upsert failed for user \(user.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
        }

        return BackendUser(id: user.id.uuidString, username: username, email: user.email ?? email)
    }

    // MARK: - Login
    func login(email: String, password: String) async throws -> BackendUser {
        let response = try await client.auth.signIn(email: email, password: password)
        let user = response.user
        let username = (try? await fetchUsername(userID: user.id.uuidString)) ?? user.email ?? email
        return BackendUser(id: user.id.uuidString, username: username, email: user.email ?? email)
    }

    func loginWithApple(idToken: String, nonce: String, suggestedUsername: String?) async throws -> BackendUser {
        let response = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        let user = response.user

        if let suggestedUsername, !suggestedUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                _ = try await client
                    .from("profiles")
                    .upsert([
                        "id": user.id.uuidString,
                        "username": suggestedUsername
                    ], onConflict: "id")
                    .execute()
            } catch {
                logger.warning("Profile upsert after Apple sign-in failed for user \(user.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        let username = (try? await fetchUsername(userID: user.id.uuidString))
            ?? suggestedUsername
            ?? user.email
            ?? "Apple User"

        return BackendUser(id: user.id.uuidString, username: username, email: user.email ?? "")
    }

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: SupabaseConfig.passwordResetRedirectURL
        )
    }

    // MARK: - Logout
    func logout() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Session & User
    func currentSession() async throws -> Session? {
        try await client.auth.session
    }

    func currentUser() async throws -> BackendUser? {
        let user: User
        do {
            user = try await client.auth.user()
        } catch {
            logger.debug("No active auth user/session found: \(String(describing: error), privacy: .public)")
            return nil
        }
        let username = (try? await fetchUsername(userID: user.id.uuidString)) ?? user.email ?? "User"
        return BackendUser(id: user.id.uuidString, username: username, email: user.email ?? "")
    }

    private func fetchUsername(userID: String) async throws -> String? {
        let rows: [SBProfileRow] = try await client
            .from("profiles")
            .select("id, username")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first?.username
    }
}
