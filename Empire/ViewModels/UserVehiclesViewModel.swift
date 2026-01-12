import Foundation
import SwiftUI

final class VehiclesViewModel: ObservableObject {
    @Published var vehicles: [Car] = []
    
    func loadVehicles() async {
        // Minimal stub: no loading implementation
    }
    
    func add(vehicle: Car) {
        vehicles.append(vehicle)
    }
    
    func remove(vehicle: Car) {
        vehicles.removeAll { $0.id == vehicle.id }
    }
}
