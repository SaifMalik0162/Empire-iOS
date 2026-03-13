import XCTest
@testable import Empire

final class MerchMappingTests: XCTestCase {
    func testMapRowsToMerchItems_fallbacksUnknownCategoryToApparel() {
        let rows = [
            SBMerchRow(id: "1", name: "Hat", price_string: "$20", image_name: "hat", category: "Accessories", updated_at: nil),
            SBMerchRow(id: "2", name: "Mystery", price_string: "$10", image_name: "mystery", category: "UnknownCategory", updated_at: nil)
        ]

        let items = SupabaseMerchService.mapRowsToMerchItems(rows)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].category, .accessories)
        XCTAssertEqual(items[1].category, .apparel)
    }
}
