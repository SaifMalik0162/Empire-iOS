import XCTest
@testable import Empire

final class AuthViewModelTests: XCTestCase {
    func testCheckAuthStatus_authenticatedWhenSessionValidAndUserExists() async {
        let auth = MockAuthService()
        auth.hasValidSessionValue = true
        auth.currentUserValue = BackendUser(id: "u1", username: "saif", email: "saif@example.com", avatarPath: nil)
        let cars = MockCarsService()

        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: cars, autoCheckStatus: false)
        }

        await vm.checkAuthStatus()

        let isAuthenticated = await MainActor.run { vm.isAuthenticated }
        XCTAssertTrue(isAuthenticated)
        XCTAssertEqual(cars.fetchCalls, 1)
    }

    func testCheckAuthStatus_unauthenticatedWhenNoValidSession() async {
        let auth = MockAuthService()
        auth.hasValidSessionValue = false
        auth.currentUserValue = nil

        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: MockCarsService(), autoCheckStatus: false)
        }

        await vm.checkAuthStatus()

        let isAuthenticated = await MainActor.run { vm.isAuthenticated }
        XCTAssertFalse(isAuthenticated)
    }

    func testLogin_setsAuthenticatedStateAndSyncsCars() async throws {
        let auth = MockAuthService()
        auth.loginResult = BackendUser(id: "login-user", username: "loginname", email: "login@gmail.com", avatarPath: nil)
        let cars = MockCarsService()

        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: cars, autoCheckStatus: false)
        }

        try await vm.login(email: "login@gmail.com", password: "secret123")

        let state = await MainActor.run { (vm.isAuthenticated, vm.currentUser, vm.shouldPromptAddVehicle) }
        XCTAssertTrue(state.0)
        XCTAssertEqual(state.1?.id, "login-user")
        XCTAssertFalse(state.2)
        XCTAssertEqual(auth.loginCalls.count, 1)
        XCTAssertEqual(auth.loginCalls.first?.email, "login@gmail.com")
        XCTAssertEqual(cars.fetchCalls, 1)
    }

    func testGoogleLogin_setsAuthenticatedStateAndPassesTokens() async throws {
        let auth = MockAuthService()
        auth.googleLoginResult = BackendUser(id: "google-user", username: "googler", email: "user@gmail.com", avatarPath: nil)
        let cars = MockCarsService()

        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: cars, autoCheckStatus: false)
        }

        try await vm.loginWithGoogle(idToken: "google-id-token", accessToken: "google-access-token", nonce: "google-nonce")

        let state = await MainActor.run { (vm.isAuthenticated, vm.currentUser) }
        XCTAssertTrue(state.0)
        XCTAssertEqual(state.1?.id, "google-user")
        XCTAssertEqual(auth.googleLoginCalls.count, 1)
        XCTAssertEqual(auth.googleLoginCalls.first?.idToken, "google-id-token")
        XCTAssertEqual(auth.googleLoginCalls.first?.accessToken, "google-access-token")
        XCTAssertEqual(auth.googleLoginCalls.first?.nonce, "google-nonce")
        XCTAssertEqual(cars.fetchCalls, 1)
    }

    func testAppleLogin_setsAuthenticatedStateAndPassesNonce() async throws {
        let auth = MockAuthService()
        auth.appleLoginResult = BackendUser(id: "apple-user", username: "appleuser", email: "user@icloud.com", avatarPath: nil)
        let cars = MockCarsService()

        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: cars, autoCheckStatus: false)
        }

        try await vm.loginWithApple(idToken: "apple-id-token", nonce: "apple-nonce", suggestedUsername: "Saif")

        let state = await MainActor.run { (vm.isAuthenticated, vm.currentUser) }
        XCTAssertTrue(state.0)
        XCTAssertEqual(state.1?.id, "apple-user")
        XCTAssertEqual(auth.appleLoginCalls.count, 1)
        XCTAssertEqual(auth.appleLoginCalls.first?.idToken, "apple-id-token")
        XCTAssertEqual(auth.appleLoginCalls.first?.nonce, "apple-nonce")
        XCTAssertEqual(auth.appleLoginCalls.first?.suggestedUsername, "Saif")
        XCTAssertEqual(cars.fetchCalls, 1)
    }

    func testSendPasswordReset_passesTrimmedEmailThroughCaller() async throws {
        let auth = MockAuthService()
        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: MockCarsService(), autoCheckStatus: false)
        }

        try await vm.sendPasswordReset(email: "user@gmail.com")

        XCTAssertEqual(auth.passwordResetEmails, ["user@gmail.com"])
    }

    func testHandleIncomingURL_presentsPasswordRecoveryWhenRecoveryLinkAccepted() async {
        let auth = MockAuthService()
        auth.beginPasswordRecoveryResult = true
        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: MockCarsService(), autoCheckStatus: false)
        }

        await vm.handleIncomingURL(URL(string: "empireconnect://auth/reset-password#access_token=test")!)

        let isPresenting = await MainActor.run { vm.isPresentingPasswordRecovery }
        XCTAssertTrue(isPresenting)
        XCTAssertEqual(auth.beginPasswordRecoveryURLs.count, 1)
    }

    func testHandleIncomingURL_authenticatesWhenSignupCallbackCompletesSession() async {
        let auth = MockAuthService()
        auth.completedAuthCallbackUser = BackendUser(id: "confirmed-user", username: "confirmed", email: "confirmed@example.com", avatarPath: nil)
        let cars = MockCarsService()
        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: cars, autoCheckStatus: false)
        }

        await vm.handleIncomingURL(URL(string: "empireconnect://auth/callback#type=signup")!)

        let state = await MainActor.run { (vm.isAuthenticated, vm.currentUser?.id) }
        XCTAssertTrue(state.0)
        XCTAssertEqual(state.1, "confirmed-user")
        XCTAssertEqual(auth.completedAuthCallbackURLs.count, 1)
        XCTAssertEqual(cars.fetchCalls, 1)
    }

    func testHandleIncomingURL_presentsPasswordRecoveryForResetPathCallback() async {
        let auth = MockAuthService()
        auth.beginPasswordRecoveryResult = true
        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: MockCarsService(), autoCheckStatus: false)
        }

        await vm.handleIncomingURL(URL(string: "empireconnect://auth/reset-password?code=test-code")!)

        let isPresenting = await MainActor.run { vm.isPresentingPasswordRecovery }
        XCTAssertTrue(isPresenting)
        XCTAssertEqual(auth.beginPasswordRecoveryURLs.count, 1)
    }

    func testHandleIncomingURL_ignoresNonRecoveryLinks() async {
        let auth = MockAuthService()
        auth.beginPasswordRecoveryResult = false
        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: MockCarsService(), autoCheckStatus: false)
        }

        await vm.handleIncomingURL(URL(string: "empireconnect://auth/callback")!)

        let isPresenting = await MainActor.run { vm.isPresentingPasswordRecovery }
        XCTAssertFalse(isPresenting)
    }

    func testCompletePasswordReset_forwardsPasswordToAuthService() async throws {
        let auth = MockAuthService()
        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: MockCarsService(), autoCheckStatus: false)
        }

        try await vm.completePasswordReset("new-password-123")

        XCTAssertEqual(auth.completedPasswordResets, ["new-password-123"])
    }

    func testDismissPasswordRecovery_clearsPresentationFlag() async {
        let auth = MockAuthService()
        auth.beginPasswordRecoveryResult = true
        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: MockCarsService(), autoCheckStatus: false)
        }

        await vm.handleIncomingURL(URL(string: "empireconnect://auth/reset-password#access_token=test")!)
        await MainActor.run { vm.dismissPasswordRecovery() }

        let isPresenting = await MainActor.run { vm.isPresentingPasswordRecovery }
        XCTAssertFalse(isPresenting)
    }

    func testRegister_acceptsNonGmailEmail() async throws {
        let auth = MockAuthService()
        auth.registerResult = BackendUser(id: "registered-non-gmail", username: "saif", email: "user@example.com", avatarPath: nil)
        let cars = MockCarsService()
        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: cars, autoCheckStatus: false)
        }

        try await vm.register(email: "user@example.com", password: "hunter22", username: "saif")

        let state = await MainActor.run { (vm.isAuthenticated, vm.currentUser) }
        XCTAssertTrue(state.0)
        XCTAssertEqual(state.1?.email, "user@example.com")
        XCTAssertEqual(auth.registerCalls.count, 1)
        XCTAssertEqual(auth.registerCalls.first?.email, "user@example.com")
        XCTAssertEqual(cars.fetchCalls, 1)
    }

    func testRegister_doesNotAuthenticateWhenEmailConfirmationIsRequired() async {
        let auth = MockAuthService()
        auth.registerError = AuthUserFacingError.emailConfirmationRequired
        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: MockCarsService(), autoCheckStatus: false)
        }

        do {
            try await vm.register(email: "user@example.com", password: "hunter22", username: "saif")
            XCTFail("Expected email confirmation to be required")
        } catch AuthUserFacingError.emailConfirmationRequired {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let state = await MainActor.run { (vm.isAuthenticated, vm.currentUser) }
        XCTAssertFalse(state.0)
        XCTAssertNil(state.1)
    }

    func testRegister_normalizesGmailAndAuthenticatesUser() async throws {
        let auth = MockAuthService()
        auth.registerResult = BackendUser(id: "registered", username: "saif", email: "user@gmail.com", avatarPath: nil)
        let cars = MockCarsService()

        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: cars, autoCheckStatus: false)
        }

        try await vm.register(email: "  User@Gmail.com ", password: "hunter22", username: "saif")

        let state = await MainActor.run { (vm.isAuthenticated, vm.currentUser) }
        XCTAssertTrue(state.0)
        XCTAssertEqual(state.1?.id, "registered")
        XCTAssertEqual(auth.registerCalls.count, 1)
        XCTAssertEqual(auth.registerCalls.first?.email, "user@gmail.com")
        XCTAssertEqual(cars.fetchCalls, 1)
    }

    func testUpdateUsername_updatesCurrentUser() async throws {
        let auth = MockAuthService()
        auth.updatedUsernameResult = BackendUser(id: "u2", username: "oldname", email: "u2@example.com", avatarPath: nil)

        let vm = await MainActor.run {
            AuthViewModel(authService: auth, carsService: MockCarsService(), autoCheckStatus: false)
        }

        try await vm.updateUsername("newname")

        let user = await MainActor.run { vm.currentUser }
        XCTAssertEqual(user?.username, "newname")
    }
}

private final class MockAuthService: AuthServiceProviding {
    var hasValidSessionValue = false
    var currentUserValue: BackendUser?
    var loginResult = BackendUser(id: "login", username: "user", email: "u@example.com", avatarPath: nil)
    var googleLoginResult = BackendUser(id: "google", username: "googleuser", email: "u@gmail.com", avatarPath: nil)
    var appleLoginResult = BackendUser(id: "apple", username: "appleuser", email: "u@icloud.com", avatarPath: nil)
    var registerResult = BackendUser(id: "register", username: "user", email: "u@gmail.com", avatarPath: nil)
    var registerError: Error?
    var updatedUsernameResult: BackendUser = .init(id: "id", username: "user", email: "u@example.com", avatarPath: nil)
    var beginPasswordRecoveryResult = true
    var completedAuthCallbackUser: BackendUser?

    var loginCalls: [(email: String, password: String)] = []
    var googleLoginCalls: [(idToken: String, accessToken: String?, nonce: String?)] = []
    var appleLoginCalls: [(idToken: String, nonce: String, suggestedUsername: String?)] = []
    var beginPasswordRecoveryURLs: [URL] = []
    var completedAuthCallbackURLs: [URL] = []
    var completedPasswordResets: [String] = []
    var passwordResetEmails: [String] = []
    var registerCalls: [(email: String, password: String, username: String)] = []

    func hasValidSession() async throws -> Bool { hasValidSessionValue }
    func currentUser() async throws -> BackendUser? { currentUserValue }

    func login(email: String, password: String) async throws -> BackendUser {
        loginCalls.append((email, password))
        return loginResult
    }

    func loginWithGoogle(idToken: String, accessToken: String?, nonce: String?) async throws -> BackendUser {
        googleLoginCalls.append((idToken, accessToken, nonce))
        return googleLoginResult
    }

    func loginWithApple(idToken: String, nonce: String, suggestedUsername: String?) async throws -> BackendUser {
        appleLoginCalls.append((idToken, nonce, suggestedUsername))
        return appleLoginResult
    }

    func beginPasswordRecovery(from url: URL) async throws -> Bool {
        beginPasswordRecoveryURLs.append(url)
        return beginPasswordRecoveryResult
    }

    func completeAuthCallback(from url: URL) async throws -> BackendUser? {
        completedAuthCallbackURLs.append(url)
        return completedAuthCallbackUser
    }

    func completePasswordReset(newPassword: String) async throws {
        completedPasswordResets.append(newPassword)
    }

    func sendPasswordReset(email: String) async throws {
        passwordResetEmails.append(email)
    }

    func register(email: String, password: String, username: String) async throws -> BackendUser {
        registerCalls.append((email, password, username))
        if let registerError {
            throw registerError
        }
        return registerResult
    }

    func logout() async throws {}

    func updateAvatarPath(_ avatarPath: String) async throws -> BackendUser { updatedUsernameResult }
    func uploadAvatar(imageData: Data) async throws -> BackendUser { updatedUsernameResult }

    func updateUsername(_ username: String) async throws -> BackendUser {
        BackendUser(
            id: updatedUsernameResult.id,
            username: username,
            email: updatedUsernameResult.email,
            avatarPath: updatedUsernameResult.avatarPath
        )
    }
}

private final class MockCarsService: CarsServiceProviding {
    var fetchCalls = 0

    func fetchCars(for userId: String) async throws -> [Car] {
        fetchCalls += 1
        return []
    }
}
