import XCTest
@testable import Empire

@MainActor
final class ProfileStatsViewModelTests: XCTestCase {
    func testLoadPopulatesCountsFromService() async {
        let service = MockProfileStatsService(meetsCount: 4, merchCount: 7)
        let vm = ProfileStatsViewModel(service: service)

        await vm.load(for: "user-123")

        XCTAssertEqual(vm.meetsCount, 4)
        XCTAssertEqual(vm.merchCount, 7)
        XCTAssertEqual(service.receivedUserIDs, ["user-123", "user-123"])
    }

    func testLoadWithEmptyUserIDResetsCountsWithoutCallingService() async {
        let service = MockProfileStatsService(meetsCount: 4, merchCount: 7)
        let vm = ProfileStatsViewModel(service: service)

        await vm.load(for: "   ")

        XCTAssertEqual(vm.meetsCount, 0)
        XCTAssertEqual(vm.merchCount, 0)
        XCTAssertTrue(service.receivedUserIDs.isEmpty)
    }
}

private final class MockProfileStatsService: ProfileStatsServiceProviding {
    let meetsCount: Int
    let merchCount: Int
    var receivedUserIDs: [String] = []

    init(meetsCount: Int, merchCount: Int) {
        self.meetsCount = meetsCount
        self.merchCount = merchCount
    }

    func countMeetRSVPs(for userId: String) async throws -> Int {
        receivedUserIDs.append(userId)
        return meetsCount
    }

    func countMerchOrders(for userId: String) async throws -> Int {
        receivedUserIDs.append(userId)
        return merchCount
    }
}
