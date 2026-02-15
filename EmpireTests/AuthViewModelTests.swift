import XCTest
@testable import Empire

final class AuthViewModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure clean state
        NetworkManager.shared.clearAuthToken()
    }

    override func tearDown() {
        NetworkManager.shared.clearAuthToken()
        super.tearDown()
    }

    private func writeKeychain(key: String, value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: value.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func testCheckAuthStatus_setsAuthenticatedWhenTokenPresent() async {
        writeKeychain(key: "com.empire.accessToken", value: "fake_access")
        writeKeychain(key: "com.empire.refreshToken", value: "fake_refresh")

        let vm = await MainActor.run { AuthViewModel() }
        let isAuth = await MainActor.run { vm.isAuthenticated }
        XCTAssertTrue(isAuth, "AuthViewModel should be authenticated when NetworkManager has tokens")
    }

    func testLogout_clearsTokensAndState() async {
        writeKeychain(key: "com.empire.accessToken", value: "fake_access")
        writeKeychain(key: "com.empire.refreshToken", value: "fake_refresh")

        let vm = await MainActor.run { AuthViewModel() }
        let isAuth = await MainActor.run { vm.isAuthenticated }
        XCTAssertTrue(isAuth)

        await MainActor.run { vm.logout() }

        XCTAssertFalse(NetworkManager.shared.isAuthenticated, "NetworkManager should report not authenticated after logout")
        let isAuthAfter = await MainActor.run { vm.isAuthenticated }
        XCTAssertFalse(isAuthAfter, "AuthViewModel should be not authenticated after logout")
    }
}
