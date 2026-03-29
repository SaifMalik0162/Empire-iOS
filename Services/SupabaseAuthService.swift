import Foundation
import Supabase
import OSLog
import UIKit
import GoogleSignIn

enum AuthUserFacingError: LocalizedError {
    case weakPassword
    case emailAlreadyRegistered
    case emailConfirmationRequired
    case invalidCredentials
    case signupDisabled
    case emailNotConfirmed
    case rateLimited
    case invalidEmail
    case samePassword
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .weakPassword:
            return "Use a stronger password with at least 8 characters and a mix of letters, numbers, or symbols."
        case .emailAlreadyRegistered:
            return "That email is already registered. Log in instead, or use Sign in with Apple."
        case .emailConfirmationRequired:
            return "Check your Gmail inbox and confirm your email before logging in."
        case .invalidCredentials:
            return "Incorrect email or password."
        case .signupDisabled:
            return "Email sign-up is currently unavailable."
        case .emailNotConfirmed:
            return "Check your inbox and confirm your email before logging in."
        case .rateLimited:
            return "Too many attempts right now. Please wait a bit and try again."
        case .invalidEmail:
            return "Enter a valid email address."
        case .samePassword:
            return "Choose a new password that is different from your current password."
        case .generic(let message):
            return message
        }
    }
}

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
        let response: AuthResponse
        do {
            response = try await client.auth.signUp(
                email: email,
                password: password,
                data: [
                    "username": .string(normalizedUsername),
                    "display_name": .string(normalizedUsername),
                    "full_name": .string(normalizedUsername)
                ]
            )
        } catch {
            throw mapAuthError(error)
        }
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

        guard response.session != nil else {
            throw AuthUserFacingError.emailConfirmationRequired
        }

        return try await backendUser(for: user, fallbackEmail: email, fallbackUsername: normalizedUsername)
    }

    // MARK: - Login
    func login(email: String, password: String) async throws -> BackendUser {
        let response: Session
        do {
            response = try await client.auth.signIn(email: email, password: password)
        } catch {
            throw mapAuthError(error)
        }
        let user = response.user
        return try await backendUser(for: user, fallbackEmail: email)
    }

    func loginWithGoogle(idToken: String, accessToken: String?, nonce: String?) async throws -> BackendUser {
        let session: Session
        do {
            session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken,
                    nonce: nonce
                )
            )
        } catch {
            throw mapAuthError(error)
        }

        let user = session.user
        return try await backendUser(for: user, fallbackEmail: user.email ?? "")
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
        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: SupabaseConfig.passwordResetRedirectURL
            )
        } catch {
            throw mapAuthError(error)
        }
    }

    func beginPasswordRecovery(from url: URL) async throws -> Bool {
        guard Self.isPasswordRecoveryURL(url) else { return false }
        _ = try await client.auth.session(from: url)
        return true
    }

    func completePasswordReset(newPassword: String) async throws {
        do {
            _ = try await client.auth.update(
                user: UserAttributes(password: newPassword)
            )
        } catch {
            throw mapAuthError(error)
        }
    }

    // MARK: - Logout
    func logout() async throws {
        GIDSignIn.sharedInstance.signOut()
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

    private func mapAuthError(_ error: Error) -> Error {
        guard let authError = error as? AuthError else {
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return AuthUserFacingError.generic(message.isEmpty ? "Something went wrong. Please try again." : message)
        }

        switch authError {
        case .weakPassword(_, _):
            return AuthUserFacingError.weakPassword
        case .api(let message, let errorCode, _, _):
            switch errorCode {
            case .emailExists, .userAlreadyExists, .conflict:
                return AuthUserFacingError.emailAlreadyRegistered
            case .weakPassword:
                return AuthUserFacingError.weakPassword
            case .signupDisabled:
                return AuthUserFacingError.signupDisabled
            case .invalidCredentials:
                return AuthUserFacingError.invalidCredentials
            case .emailNotConfirmed:
                return AuthUserFacingError.emailNotConfirmed
            case .overRequestRateLimit, .overEmailSendRateLimit:
                return AuthUserFacingError.rateLimited
            case .samePassword:
                return AuthUserFacingError.samePassword
            case .validationFailed:
                return AuthUserFacingError.invalidEmail
            default:
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                return AuthUserFacingError.generic(trimmed.isEmpty ? "Something went wrong. Please try again." : trimmed)
            }
        default:
            let trimmed = authError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return AuthUserFacingError.generic(trimmed.isEmpty ? "Something went wrong. Please try again." : trimmed)
        }
    }

    private static func isPasswordRecoveryURL(_ url: URL) -> Bool {
        let params = authCallbackParams(from: url)
        return params["type"] == "recovery"
    }

    private static func authCallbackParams(from url: URL) -> [String: String] {
        var result: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for item in components.queryItems ?? [] {
                result[item.name] = item.value
            }
        }

        if let fragment = URLComponents(string: "empire://callback?\(url.fragment ?? "")") {
            for item in fragment.queryItems ?? [] {
                result[item.name] = item.value
            }
        }

        return result
    }
}
