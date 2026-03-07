import XCTest
@testable import Empire

final class AuthViewModelTests: XCTestCase {

    // Test helpers for token setup/teardown
    private func writeToken(_ key: String, _ value: String) {
        let data = value.data(using: .utf8)!
        _ = KeychainService.shared.save(data, forKey: key)
    }

    private func clearTokens() {
        _ = KeychainService.shared.delete(forKey: KeychainService.accessTokenKey)
        _ = KeychainService.shared.delete(forKey: KeychainService.refreshTokenKey)
    }

    override func setUp() {
        super.setUp()
        // Ensure clean state
        clearTokens()
    }

    override func tearDown() {
        clearTokens()
        super.tearDown()
    }

    func testCheckAuthStatus_setsAuthenticatedWhenTokenPresent() async {
        writeToken(KeychainService.accessTokenKey, "fake_access")
        writeToken(KeychainService.refreshTokenKey, "fake_refresh")

        let vm = await MainActor.run { AuthViewModel() }
        let isAuth = await MainActor.run { vm.isAuthenticated }
        XCTAssertTrue(isAuth, "AuthViewModel should be authenticated when NetworkManager has tokens")
    }

    func testLogout_clearsTokensAndState() async {
        writeToken(KeychainService.accessTokenKey, "fake_access")
        writeToken(KeychainService.refreshTokenKey, "fake_refresh")

        let vm = await MainActor.run { AuthViewModel() }
        let isAuth = await MainActor.run { vm.isAuthenticated }
        XCTAssertTrue(isAuth)

        await MainActor.run { vm.logout() }

        XCTAssertFalse(NetworkManager.shared.isAuthenticated, "NetworkManager should report not authenticated after logout")
        let isAuthAfter = await MainActor.run { vm.isAuthenticated }
        XCTAssertFalse(isAuthAfter, "AuthViewModel should be not authenticated after logout")
    }
}

