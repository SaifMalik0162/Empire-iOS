import Foundation
import SwiftUI
import Combine

final class UserVehiclesViewModel: ObservableObject {
    @Published var vehicles: [Car] = []

    private var userKey: String { UserDefaults.standard.string(forKey: "currentUserId") ?? "default" }
    private var vehiclesKey: String { "saved_user_vehicles_\(userKey)" }

    private func persistVehicles() {
        if let data = try? JSONEncoder().encode(vehicles) {
            UserDefaults.standard.set(data, forKey: vehiclesKey)
        }
    }

    @MainActor
    @discardableResult
    func addPlaceholderVehicleAndReturnIndex() -> Int? {
        #if DEBUG
        let placeholder = Car(
            name: "Your Car",
            description: "Tap to edit details",
            imageName: "car_placeholder",
            horsepower: 0,
            stage: 1,
            specs: [],
            mods: []
        )
        vehicles.append(placeholder)
        persistVehicles()
        return vehicles.indices.last
        #else
        return nil
        #endif
    }

    init() {}

    @MainActor
    func loadVehicles() async {
        if let data = UserDefaults.standard.data(forKey: vehiclesKey),
           let decoded = try? JSONDecoder().decode([Car].self, from: data) {
            vehicles = decoded
        }
    }

    @MainActor
    func addPlaceholderVehicle() {
        #if DEBUG
        let placeholder = Car(name: "Your Car", description: "Tap to edit details", imageName: "car_placeholder", horsepower: 0, stage: 1)
        vehicles.append(placeholder)
        persistVehicles()
        #endif
    }

    @MainActor
    func removeVehicles(at offsets: IndexSet) {
        vehicles.remove(atOffsets: offsets)
        persistVehicles()
    }
    
    @MainActor
    func updateVehicle(at index: Int, with updated: Car) {
        guard vehicles.indices.contains(index) else { return }
        vehicles[index] = updated
        persistVehicles()
    }

    @MainActor
    func append(_ car: Car) {
        vehicles.append(car)
        persistVehicles()
    }
}
