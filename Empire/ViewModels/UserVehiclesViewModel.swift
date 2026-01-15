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
    func addPlaceholderVehicleAndReturnIndex() async -> Int?  {
        #if DEBUG
        do {
            guard let userIdString = UserDefaults.standard.string(forKey: "currentUserId"),
                  let userId = Int(userIdString) else {
                print("❌ No user ID found")
                throw NSError(domain: "UserVehiclesVM", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
            }
            
            print("🚗 Creating car for user ID: \(userId)")
            
            let backendCar = try await APIService.shared.createCar(
                make:  "Your",      // ← FIXED: Real value!
                model: "Car",      // ← FIXED: Simple default
                year: 2024,
                color: nil,
                horsepower: 0,
                stage: "1",
                userId: userId
            )
            
            print("✅ Backend returned car with ID: \(backendCar.id)")
            
            let newCar = Car(
                backendId: backendCar.id,
                name: "\(backendCar.make) \(backendCar.model)",  // ← FIXED: Use both!
                description: "Tap to edit details",
                imageName:  backendCar.imageUrl ??  "car_placeholder",
                horsepower: backendCar.horsepower ?? 0,
                stage: Int(backendCar.stage ?? "1") ?? 1,
                specs: [],
                mods: []
            )
            
            print("✅ Created local car with backendId: \(newCar.backendId ??  -1)")
            
            vehicles.append(newCar)
            persistVehicles()
            return vehicles.indices.last
            
        } catch {
            print("❌ Failed to create car on backend: \(error)")
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
        }
        #else
        return nil
        #endif
    }

    init() {}

    @MainActor
    func loadVehicles() async {
        do {
            let backendCars = try await APIService.shared.getAllCars()
            
            vehicles = backendCars.map { backendCar in
                Car(
                    backendId:  backendCar.id,
                    name: "\(backendCar.make) \(backendCar.model)",  // ← FIXED: Use both!
                    description: "\(backendCar.year) · \(backendCar.color ??  "No color")",
                    imageName: backendCar.imageUrl ?? "car_placeholder",
                    horsepower: backendCar.horsepower ?? 0,
                    stage: Int(backendCar.stage ?? "0") ?? 0,
                    specs: [],
                    mods: []
                )
            }
            
            persistVehicles()
            
        } catch {
            print("⚠️ Failed to load cars from backend: \(error)")
            if let data = UserDefaults.standard.data(forKey: vehiclesKey),
               let decoded = try? JSONDecoder().decode([Car].self, from: data) {
                vehicles = decoded
            }
        }
    }

    @MainActor
    func addPlaceholderVehicle() async {
        #if DEBUG
        do {
            guard let userIdString = UserDefaults.standard.string(forKey: "currentUserId"),
                  let userId = Int(userIdString) else {
                print("❌ No user ID found")
                let placeholder = Car(name: "Your Car", description: "Tap to edit details", imageName: "car_placeholder", horsepower: 0, stage: 1)
                vehicles.append(placeholder)
                persistVehicles()
                return
            }
            
            print("🚗 Creating car for user ID: \(userId)")
            
            let backendCar = try await APIService.shared.createCar(
                make: "Your",      // ← FIXED: Real value!
                model: "Car",      // ← FIXED: Simple default
                year: 2024,
                color: nil,
                horsepower: 0,
                stage: "1",
                userId: userId
            )
            
            let newCar = Car(
                backendId: backendCar.id,
                name: "\(backendCar.make) \(backendCar.model)",  // ← FIXED: Use both!
                description: "Tap to edit details",
                imageName: backendCar.imageUrl ?? "car_placeholder",
                horsepower: backendCar.horsepower ?? 0,
                stage: Int(backendCar.stage ?? "1") ?? 1,
                specs: [],
                mods:  []
            )
            
            vehicles.append(newCar)
            persistVehicles()
            
        } catch {
            print("❌ Failed to create car on backend: \(error)")
            let placeholder = Car(name: "Your Car", description: "Tap to edit details", imageName: "car_placeholder", horsepower: 0, stage: 1)
            vehicles.append(placeholder)
            persistVehicles()
        }
        #endif
    }

    @MainActor
    func removeVehicles(at offsets: IndexSet) async {
        for index in offsets {
            guard vehicles.indices.contains(index) else { continue }
            let car = vehicles[index]
            
            if let backendId = car.backendId {
                do {
                    try await APIService.shared.deleteCar(id: backendId)
                    print("✅ Deleted car \(backendId) from backend")
                } catch {
                    print("❌ Failed to delete car from backend: \(error)")
                }
            }
        }
        
        vehicles.remove(atOffsets: offsets)
        persistVehicles()
    }
    
    @MainActor
    func updateVehicle(at index: Int, with updated: Car) async {
        guard vehicles.indices.contains(index) else { return }
        
        vehicles[index] = updated
        persistVehicles()
        
        guard let backendId = updated.backendId else {
            print("⚠️ Car has no backend ID, skipping backend sync")
            return
        }
        
        print("🔄 Updating car \(backendId) on backend...")
        print("📝 Car data: name=\(updated.name), hp=\(updated.horsepower), stage=\(updated.stage)")
        
        // ✅ FIXED: Parse make and model from name
        let parts = updated.name.split(separator: " ", maxSplits: 1)
        let make:  String
        let model: String
        
        if parts.count >= 2 {
            make = String(parts[0])
            model = String(parts[1])
        } else if parts.count == 1 {
            make = String(parts[0])
            model = "Car"
        } else {
            make = "Your"
            model = "Car"
        }
        
        // Parse year from description (format: "2024 · Color")
        let descParts = updated.description.split(separator: "·")
        let yearString = descParts.first?.trimmingCharacters(in: .whitespaces) ?? "2024"
        let year = Int(yearString) ?? 2024
        let color = descParts.count > 1 ? descParts[1].trimmingCharacters(in: . whitespaces) : nil
        
        print("🔍 Parsed:  make=\(make), model=\(model), year=\(year), color=\(color ?? "nil")")
        
        do {
            let backendCar = try await APIService.shared.updateCar(
                id: backendId,
                make: make,
                model: model,
                year: year,
                color: color,
                horsepower: updated.horsepower,
                stage: String(updated.stage)
            )
            print("✅ Updated car \(backendId) on backend")
            
        } catch {
            print("❌ Failed to update car on backend: \(error)")
        }
    }

    @MainActor
    func append(_ car: Car) {
        vehicles.append(car)
        persistVehicles()
    }
}
