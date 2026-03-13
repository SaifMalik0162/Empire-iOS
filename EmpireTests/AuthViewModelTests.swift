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
    var updatedUsernameResult: BackendUser = .init(id: "id", username: "user", email: "u@example.com", avatarPath: nil)

    func hasValidSession() async throws -> Bool { hasValidSessionValue }
    func currentUser() async throws -> BackendUser? { currentUserValue }
    func login(email: String, password: String) async throws -> BackendUser { updatedUsernameResult }
    func loginWithApple(idToken: String, nonce: String, suggestedUsername: String?) async throws -> BackendUser { updatedUsernameResult }
    func sendPasswordReset(email: String) async throws {}
    func register(email: String, password: String, username: String) async throws -> BackendUser { updatedUsernameResult }
    func logout() async throws {}
    func updateAvatarPath(_ avatarPath: String) async throws -> BackendUser { updatedUsernameResult }
    func uploadAvatar(imageData: Data) async throws -> BackendUser { updatedUsernameResult }
    func updateUsername(_ username: String) async throws -> BackendUser {
        BackendUser(id: updatedUsernameResult.id, username: username, email: updatedUsernameResult.email, avatarPath: updatedUsernameResult.avatarPath)
    }
}

private final class MockCarsService: CarsServiceProviding {
    var fetchCalls = 0

    func fetchCars(for userId: String) async throws -> [Car] {
        fetchCalls += 1
        return []
    }
}

