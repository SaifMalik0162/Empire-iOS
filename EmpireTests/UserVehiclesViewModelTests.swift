import XCTest
@testable import Empire

final class UserVehiclesViewModelTests: XCTestCase {

    let userIdKey = "currentUserId"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: userIdKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        super.tearDown()
    }

    func testAppendAndPersistLoadsBack() async throws {
        UserDefaults.standard.set("test_user_1", forKey: userIdKey)

        let vm = UserVehiclesViewModel()
        let car = Car(name: "TestCar", description: "desc", imageName: "car_placeholder", horsepower: 100, stage: 1)

        await MainActor.run {
            vm.append(car)
        }

        // Create a fresh instance and loadVehicles to ensure persistence
        let vm2 = UserVehiclesViewModel()
        await vm2.loadVehicles()

        XCTAssertEqual(vm2.vehicles.count, 1)
        XCTAssertEqual(vm2.vehicles.first?.name, "TestCar")
    }

    func testRemoveVehiclePersists() async throws {
        UserDefaults.standard.set("test_user_2", forKey: userIdKey)
        let vm = UserVehiclesViewModel()
        let carA = Car(name: "A", description: "a", imageName: "car_placeholder", horsepower: 10, stage: 1)
        let carB = Car(name: "B", description: "b", imageName: "car_placeholder", horsepower: 20, stage: 1)

        await MainActor.run {
            vm.append(carA)
            vm.append(carB)
        }

        await MainActor.run {
            vm.removeVehicles(at: IndexSet(integer: 0))
        }

        let vm2 = UserVehiclesViewModel()
        await vm2.loadVehicles()

        XCTAssertEqual(vm2.vehicles.count, 1)
        XCTAssertEqual(vm2.vehicles.first?.name, "B")
    }
}
