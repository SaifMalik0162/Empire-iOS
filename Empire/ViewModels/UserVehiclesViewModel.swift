import Foundation
import SwiftUI
import Combine
import SwiftData

final class UserVehiclesViewModel: ObservableObject {
    @Published var vehicles: [Car] = []
    var modelContext: ModelContext? = nil

    private var userKey: String { UserDefaults.standard.string(forKey: "currentUserId") ?? "default" }
    private var vehiclesKey: String { "saved_user_vehicles_\(userKey)" }

    private func persistVehicles() {
        if let context = modelContext {
            LocalStore.shared.replaceAllCars(vehicles, context: context, userKey: userKey)
        } else {
            if let data = try? JSONEncoder().encode(vehicles) {
                UserDefaults.standard.set(data, forKey: vehiclesKey)
            }
        }
    }

    @MainActor
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        // Attempt one-time migration from UserDefaults into SwiftData for this user
        LocalStore.shared.migrateFromUserDefaultsIfNeeded(context: context, userKey: userKey)
    }

    init() {}

    @MainActor
    func loadVehicles() async {
        if let context = modelContext {
            // Ensure migration occurs only once per session via setContext; fetch from SwiftData
            let fetched = LocalStore.shared.fetchCars(context: context, userKey: userKey)
            vehicles = fetched
            return
        }
        if let data = UserDefaults.standard.data(forKey: vehiclesKey),
           let decoded = try? JSONDecoder().decode([Car].self, from: data) {
            vehicles = decoded
        }
    }

    @MainActor
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
