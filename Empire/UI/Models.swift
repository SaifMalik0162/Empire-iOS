import SwiftUI
import CryptoKit

// MARK: - Tabs
enum EmpireTab: CaseIterable, Hashable {
    case home, meets, cars, merch, profile

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .meets: return "map.fill"
        case .cars: return "car.fill"
        case .merch: return "bag.fill"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - Meet
// `id` is now a stored property with a default value so callers that already
// rely on `Meet(title:city:date:latitude:longitude:)` continue to compile,
// while SupabaseMeetsService can inject a stable Supabase-derived UUID.
struct Meet: Identifiable, Hashable {
    let id: UUID
    let title: String
    let city: String
    let date: Date
    let latitude: Double?
    let longitude: Double?

    init(
        id: UUID = UUID(),
        title: String,
        city: String,
        date: Date,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.city = city
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Car
struct Car: Identifiable, Codable {
    var id: UUID
    var name: String
    var description: String
    var make: String? = nil
    var model: String? = nil
    var imageName: String
    var photoFileName: String? = nil
    var horsepower: Int
    var stage: Int
    var specs: [SpecItem] = []
    var mods: [ModItem] = []
    var isJailbreak: Bool = false
    var vehicleClass: VehicleClass? = nil

    init(id: UUID = UUID(), name: String, description: String, make: String? = nil, model: String? = nil, imageName: String, photoFileName: String? = nil, horsepower: Int, stage: Int, specs: [SpecItem] = [], mods: [ModItem] = [], isJailbreak: Bool = false, vehicleClass: VehicleClass? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.make = make
        self.model = model
        self.imageName = imageName
        self.photoFileName = photoFileName
        self.horsepower = horsepower
        self.stage = stage
        self.specs = specs
        self.mods = mods
        self.isJailbreak = isJailbreak
        self.vehicleClass = vehicleClass
    }
}

struct SpecItem: Identifiable, Hashable, Codable {
    var id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

struct ModItem: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var notes: String = ""
    var isMajor: Bool = false

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

struct MerchItem: Identifiable {
    let id: UUID
    let name: String
    let price: String
    let imageName: String
    let category: MerchCategory

    init(
        id: UUID? = nil,
        stableIDSeed: String? = nil,
        name: String,
        price: String,
        imageName: String,
        category: MerchCategory
    ) {
        self.id = id ?? Self.makeStableID(from: stableIDSeed ?? "\(category.rawValue)|\(imageName)|\(name)")
        self.name = name
        self.price = price
        self.imageName = imageName
        self.category = category
    }

    private static func makeStableID(from seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        let bytes = Array(digest.prefix(16))
        let uuidString = String(
            format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuidString: uuidString) ?? UUID()
    }
}
