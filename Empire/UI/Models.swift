import SwiftUI

// MARK: - Tabs
enum EmpireTab: CaseIterable, Hashable {
    case home, meets, cars, merch, profile

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case . meets: return "map.fill"
        case .cars: return "car.fill"
        case .merch: return "bag.fill"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - Meet
struct Meet: Identifiable {
    let id = UUID()
    let title: String
    let city: String
    let date: Date

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Car
struct Car: Identifiable, Codable {
    let id: UUID
    var backendId: Int?  // ← ADDED
    var name: String
    var description: String
    var imageName: String
    var horsepower: Int
    var stage: Int
    var specs: [SpecItem]
    var mods: [ModItem]
    var isJailbreak: Bool
    var vehicleClass: VehicleClass?
    
    // ← ADDED INIT
    init(id: UUID = UUID(),
         backendId: Int?  = nil,
         name: String,
         description: String,
         imageName: String,
         horsepower: Int,
         stage: Int,
         specs:  [SpecItem] = [],
         mods: [ModItem] = [],
         isJailbreak: Bool = false,
         vehicleClass: VehicleClass?  = nil) {
        self.id = id
        self.backendId = backendId
        self.name = name
        self.description = description
        self.imageName = imageName
        self.horsepower = horsepower
        self.stage = stage
        self.specs = specs
        self.mods = mods
        self.isJailbreak = isJailbreak
        self.vehicleClass = vehicleClass
    }
}

struct SpecItem: Identifiable, Hashable, Codable {
    let id:  UUID
    var key: String
    var value: String
    
    init(id: UUID = UUID(), key: String, value:  String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

struct ModItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var notes: String
    var isMajor: Bool
    
    init(id: UUID = UUID(), title: String, notes: String = "", isMajor: Bool = false) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isMajor = isMajor
    }
}

enum VehicleClass: String, CaseIterable, Identifiable, Codable {
    case a_FWD_Tuner = "A - FWD Tuner"
    case performance4Cyl = "B - Performance 4-Cylinder"
    case sixCylinderStreet = "C - 6-Cylinder Street"
    case highPerformance = "S - High-Performance Sports"
    case m_AmericanMuscle = "M - American Muscle"
    case importV8 = "I - Import V8 Performance"
    case supercar = "X - Supercars & Hypercars"
    case electricHybrid = "E - Electric & Hybrid"
    case trackOnly = "T - Track-Only"

    var id: String { rawValue }
}

// MARK: - Merch Item
enum MerchCategory: String, CaseIterable, Codable, Equatable, Hashable {
    case apparel = "Apparel"
    case accessories = "Accessories"
    case banners = "Banners"
}

struct MerchItem:  Identifiable {
    let id = UUID()
    let name: String
    let price: String
    let imageName: String
    let category:  MerchCategory
}
