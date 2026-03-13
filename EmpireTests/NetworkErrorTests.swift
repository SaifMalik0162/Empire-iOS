import XCTest
@testable import Empire

final class NetworkErrorTests: XCTestCase {
    func testNetworkErrorDescriptions() {
        XCTAssertEqual(NetworkError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(NetworkError.unauthorized.errorDescription, "Please log in again")

        let server = NetworkError.serverError("Oops")
        XCTAssertEqual(server.errorDescription, "Oops")

        let unknown = NetworkError.unknown(NSError(domain: "test", code: 99, userInfo: [NSLocalizedDescriptionKey: "Boom"]))
        XCTAssertEqual(unknown.errorDescription, "Boom")
    }
}
