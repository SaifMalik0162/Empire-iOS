import Foundation
import SwiftUI
import Combine

final class UserVehiclesViewModel: ObservableObject {
    @Published var vehicles: [Car] = []

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
        return vehicles.indices.last
        #else
        return nil
        #endif
    }

    init() {}

    @MainActor
    func loadVehicles() async {
        // TODO: Wire to backend API when available
        // For now, do nothing to keep compile-time happy
    }

    @MainActor
    func addPlaceholderVehicle() {
        // Add a simple placeholder car if a Car type is available in the project
        #if DEBUG
        let placeholder = Car(name: "Your Car", description: "Tap to edit details", imageName: "car_placeholder", horsepower: 0, stage: 1)
        vehicles.append(placeholder)
        #endif
    }

    @MainActor
    func removeVehicles(at offsets: IndexSet) {
        vehicles.remove(atOffsets: offsets)
    }
    
    @MainActor
    func updateVehicle(at index: Int, with updated: Car) {
        guard vehicles.indices.contains(index) else { return }
        vehicles[index] = updated
    }
}
