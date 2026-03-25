import Foundation
import Supabase
import OSLog
import UIKit

enum AuthProfileError: LocalizedError {
    case usernameCooldown(remaining: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .usernameCooldown(let remaining):
            let minutes = Int(ceil(remaining / 60))
            if minutes < 60 {
                return "You can change your username again in \(minutes) minute\(minutes == 1 ? "" : "s")."
            }
            let hours = Int(ceil(Double(minutes) / 60.0))
            if hours < 48 {
                return "You can change your username again in \(hours) hour\(hours == 1 ? "" : "s")."
            }
            let days = Int(ceil(Double(hours) / 24.0))
            return "You can change your username again in \(days) day\(days == 1 ? "" : "s")."
        }
    }
}

struct BackendUser: Codable, Equatable {
    let id: String
    let username: String
    let email: String
    let avatarPath: String?
}

private struct SBProfileRow: Codable {
    let id: String
    let username: String?
    let avatar_path: String?
    let last_username_change_at: String?
}

@MainActor
final class SupabaseAuthService {
    private var client: SupabaseClient { SupabaseClientProvider.client }
    private let logger = AppLogger.supabaseAuth
    private let avatarBucket = "avatars"
    private let usernameCooldown: TimeInterval = 60 * 60 * 24 * 14
    private let iso8601Formatter = ISO8601DateFormatter()

    // MARK: - Sign Up / Register
    func register(email: String, password: String, username: String) async throws -> BackendUser {
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "username": .string(normalizedUsername),
                "display_name": .string(normalizedUsername),
                "full_name": .string(normalizedUsername)
            ]
        )
        let user = response.user
        do {
            _ = try await client
                .from("profiles")
                .upsert([
                    "id": user.id.uuidString,
                    "username": normalizedUsername
                ], onConflict: "id")
                .execute()
        } catch {
            logger.warning("Profile upsert failed for user \(user.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
        }

        return try await backendUser(for: user, fallbackEmail: email, fallbackUsername: normalizedUsername)
    }

    // MARK: - Login
    func login(email: String, password: String) async throws -> BackendUser {
        let response = try await client.auth.signIn(email: email, password: password)
        let user = response.user
        return try await backendUser(for: user, fallbackEmail: email)
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
            let normalizedUsername = suggestedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                _ = try await client
                    .from("profiles")
                    .upsert([
                        "id": user.id.uuidString,
                        "username": normalizedUsername
                    ], onConflict: "id")
                    .execute()
            } catch {
                logger.warning("Profile upsert after Apple sign-in failed for user \(user.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
            }

            do {
                _ = try await client.auth.update(
                    user: UserAttributes(
                        data: [
                            "username": .string(normalizedUsername),
                            "display_name": .string(normalizedUsername),
                            "full_name": .string(normalizedUsername)
                        ]
                    )
                )
            } catch {
                logger.warning("Auth metadata update after Apple sign-in failed for user \(user.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        return try await backendUser(for: user, fallbackEmail: "", fallbackUsername: suggestedUsername)
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
    func hasValidSession() async throws -> Bool {
        guard let session = try await currentSession() else { return false }
        return !session.isExpired
    }

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
        return try await backendUser(for: user, fallbackEmail: "")
    }

    func uploadAvatar(imageData: Data) async throws -> BackendUser {
        let user = try await client.auth.user()
        let normalizedUserID = user.id.uuidString.lowercased()
        let path = "\(normalizedUserID)/avatar.jpg"

        let compressed = compressImageData(imageData, maxBytes: 600_000) ?? imageData

        try await client.storage
            .from(avatarBucket)
            .upload(
                path,
                data: compressed,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        _ = try await client
            .from("profiles")
            .upsert([
                "id": user.id.uuidString,
                "avatar_path": path
            ], onConflict: "id")
            .execute()

        return try await backendUser(for: user, fallbackEmail: user.email ?? "")
    }

    func updateAvatarPath(_ avatarPath: String) async throws -> BackendUser {
        let user = try await client.auth.user()
        _ = try await client
            .from("profiles")
            .upsert([
                "id": user.id.uuidString,
                "avatar_path": avatarPath
            ], onConflict: "id")
            .execute()
        return try await backendUser(for: user, fallbackEmail: user.email ?? "")
    }

    func updateUsername(_ username: String) async throws -> BackendUser {
        let user = try await client.auth.user()
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentProfile = try await fetchProfile(userID: user.id.uuidString)

        if let currentProfile,
           let currentUsername = currentProfile.username?.trimmingCharacters(in: .whitespacesAndNewlines),
           currentUsername.caseInsensitiveCompare(normalizedUsername) == .orderedSame {
            logger.debug("Skipped username update because value is unchanged")
            return try await backendUser(for: user, fallbackEmail: user.email ?? "", fallbackUsername: normalizedUsername)
        }

        if let currentProfile,
           let lastChangeAt = parseISODate(currentProfile.last_username_change_at),
           let currentUsername = currentProfile.username?.trimmingCharacters(in: .whitespacesAndNewlines),
           currentUsername.caseInsensitiveCompare(normalizedUsername) != .orderedSame {
            let elapsed = Date().timeIntervalSince(lastChangeAt)
            let remaining = usernameCooldown - elapsed
            if remaining > 0 {
                logger.notice("Username change blocked by cooldown. Remaining seconds: \(remaining, privacy: .public)")
                throw AuthProfileError.usernameCooldown(remaining: remaining)
            }
        }

        _ = try await client
            .from("profiles")
            .upsert([
                "id": user.id.uuidString,
                "username": normalizedUsername,
                "last_username_change_at": iso8601Formatter.string(from: Date())
            ], onConflict: "id")
            .execute()

        _ = try await client.auth.update(
            user: UserAttributes(
                data: [
                    "username": .string(normalizedUsername),
                    "display_name": .string(normalizedUsername),
                    "full_name": .string(normalizedUsername)
                ]
            )
        )

        return try await backendUser(for: user, fallbackEmail: user.email ?? "", fallbackUsername: normalizedUsername)
    }

    private func fetchProfile(userID: String) async throws -> SBProfileRow? {
        let rows: [SBProfileRow] = try await client
            .from("profiles")
            .select("id, username, avatar_path, last_username_change_at")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    private func backendUser(for user: User, fallbackEmail: String, fallbackUsername: String? = nil) async throws -> BackendUser {
        let profile = try? await fetchProfile(userID: user.id.uuidString)
        let cleanedFallbackUsername = fallbackUsername?.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = profile?.username?.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedUsername: String
        if let username, !username.isEmpty {
            resolvedUsername = username
        } else if let cleanedFallbackUsername, !cleanedFallbackUsername.isEmpty {
            resolvedUsername = cleanedFallbackUsername
        } else {
            resolvedUsername = user.email ?? fallbackEmail
        }

        return BackendUser(
            id: user.id.uuidString,
            username: resolvedUsername,
            email: user.email ?? fallbackEmail,
            avatarPath: profile?.avatar_path
        )
    }

    private func compressImageData(_ data: Data, maxBytes: Int) -> Data? {
        guard data.count > maxBytes else { return data }
        guard let image = UIImage(data: data) else { return data }

        var compression: CGFloat = 0.92
        var result = image.jpegData(compressionQuality: compression)

        while let current = result, current.count > maxBytes, compression > 0.45 {
            compression -= 0.08
            result = image.jpegData(compressionQuality: compression)
        }

        return result
    }

    private func parseISODate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let parsed = iso8601Formatter.date(from: value) {
            return parsed
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        return formatter.date(from: value)
    }
}
