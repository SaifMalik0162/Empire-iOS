import XCTest
@testable import Empire

final class StageSystemTests: XCTestCase {
    func testDragTrackAssessmentUsesQuarterMileTime() {
        let assessment = StageSystem.assessment(
            vehicleClass: .dragTrack,
            horsepower: 0,
            selectedMajorMods: ["Built Motor", "Drivetrain Swap", "Tune"],
            quarterMile: "10.1"
        )

        XCTAssertEqual(assessment.stage, .stage4)
        XCTAssertFalse(assessment.isJailbreak)
        XCTAssertEqual(assessment.majorModCount, 3)
        XCTAssertTrue(assessment.hasTune)
    }

    func testDragTrackAssessmentStaysStockWithoutQuarterMile() {
        let assessment = StageSystem.assessment(
            vehicleClass: .dragTrack,
            horsepower: 0,
            selectedMajorMods: ["Built Motor", "Drivetrain Swap", "Tune"],
            quarterMile: ""
        )

        XCTAssertEqual(assessment.stage, .stock)
        XCTAssertTrue(assessment.detail.contains("Enter the quickest verified run"))
    }
}
