import Foundation
import SwiftUI
import Combine
import SwiftData
import OSLog

@MainActor
final class UserVehiclesViewModel: ObservableObject {
    @Published var vehicles: [Car] = []
    var modelContext: ModelContext? = nil

    private let carsService = SupabaseCarsService()
    private var currentUserId: String { UserDefaults.standard.string(forKey: "currentUserId") ?? "default" }

    private var userKey: String { UserDefaults.standard.string(forKey: "currentUserId") ?? "default" }
    private var vehiclesKey: String { "saved_user_vehicles_\(userKey)" }
    
    private let logger = Logger(subsystem: "com.empire.app", category: "vehicles-sync")

    private func persistVehicles() {
        if let context = modelContext {
            LocalStore.shared.replaceAllCars(vehicles, context: context, userKey: userKey)
        } else {
            if let data = try? JSONEncoder().encode(vehicles) {
                UserDefaults.standard.set(data, forKey: vehiclesKey)
            }
        }
    }

    private func syncCarInBackground(_ car: Car) {
        Task { [self, car, userId = currentUserId] in
            do {
                try await self.retry {
                    try await self.carsService.upsertCarBundle(car, userId: userId)
                }
                self.logger.info("Successfully upserted car with id \(car.id, privacy: .public)")
            } catch {
                self.logger.error("Failed to upsert car with id \(car.id, privacy: .public): \(String(describing: error), privacy: .public)")
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
        let placeholder = Car(
            name: "Your Car",
            description: "No make/model provided",
            imageName: "car_placeholder",
            horsepower: 0,
            stage: 1,
            specs: [],
            mods: []
        )
        vehicles.append(placeholder)
        persistVehicles()
        syncCarInBackground(placeholder)
        return vehicles.indices.last
    }

    @MainActor
    func addPlaceholderVehicle() {
        let placeholder = Car(name: "Your Car", description: "No make/model provided", imageName: "car_placeholder", horsepower: 0, stage: 1)
        vehicles.append(placeholder)
        persistVehicles()
        syncCarInBackground(placeholder)
    }

    @MainActor
    func removeVehicles(at offsets: IndexSet) {
        let removedCars = offsets.compactMap { vehicles.indices.contains($0) ? vehicles[$0] : nil }
        vehicles.remove(atOffsets: offsets)
        persistVehicles()
        Task { [self, removedCars] in
            for car in removedCars {
                do {
                    try await self.retry {
                        try await self.carsService.deleteCar(id: car.id.uuidString)
                    }
                    self.logger.info("Successfully deleted car with id \(car.id, privacy: .public)")
                } catch {
                    self.logger.error("Failed to delete car with id \(car.id, privacy: .public): \(String(describing: error), privacy: .public)")
                }
            }
        }
    }
    
    @MainActor
    func updateVehicle(at index: Int, with updated: Car) {
        guard vehicles.indices.contains(index) else { return }
        vehicles[index] = updated
        persistVehicles()
        syncCarInBackground(updated)
    }

    @MainActor
    func append(_ car: Car) {
        vehicles.append(car)
        persistVehicles()
        syncCarInBackground(car)
    }
    
    private func retry<T>(times: Int = 3, delay: TimeInterval = 0.8, _ op: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 1...times {
            do { return try await op() } catch {
                lastError = error
                logger.error("Retry attempt \(attempt) failed: \(String(describing: error), privacy: .public)")
                if attempt < times { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            }
        }
        throw lastError ?? URLError(.cannotConnectToHost)
    }
}
