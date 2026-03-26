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

enum BuildStageRank: Int, CaseIterable, Codable {
    case stock = 0
    case stage1 = 1
    case stage2 = 2
    case stage3 = 3
    case stage4 = 4
    case stage5 = 5
    case maxOut = 6

    var label: String {
        switch self {
        case .stock: return "Stock"
        case .stage1: return "Stage 1"
        case .stage2: return "Stage 2"
        case .stage3: return "Stage 3"
        case .stage4: return "Stage 4"
        case .stage5: return "Stage 5"
        case .maxOut: return "MAX"
        }
    }

    var accentColor: Color {
        switch self {
        case .stock: return .gray
        case .stage1: return Color("EmpireMint")
        case .stage2: return Color(red: 0.95, green: 0.78, blue: 0.12)
        case .stage3: return Color(red: 0.98, green: 0.48, blue: 0.16)
        case .stage4: return Color(red: 0.96, green: 0.30, blue: 0.18)
        case .stage5: return Color(red: 0.88, green: 0.16, blue: 0.28)
        case .maxOut: return Color(red: 0.76, green: 0.48, blue: 1.0)
        }
    }

    static func from(rawStage: Int) -> BuildStageRank {
        BuildStageRank(rawValue: rawStage) ?? .stock
    }
}

struct StageBand: Codable, Hashable {
    let rank: BuildStageRank
    let lowerBound: Int
    let upperBound: Int?

    var horsepowerLabel: String {
        if let upperBound {
            return "\(lowerBound)-\(upperBound) HP"
        }
        return "\(lowerBound)+ HP"
    }
}

struct StageAssessment {
    let stage: BuildStageRank
    let isJailbreak: Bool
    let summary: String
    let detail: String
    let majorModCount: Int
    let hasTune: Bool
}

enum VehicleClass: String, CaseIterable, Identifiable, Codable {
    case a_FWD_Tuner = "A - FWD Tuner"
    case performance4Cyl = "B - Performance 4-Cylinder"
    case sixCylinderStreet = "C - 6-Cylinder Street"
    case dragTrack = "D - Drag & Track"
    case highPerformance = "S - High-Performance Sports"
    case m_AmericanMuscle = "M - American Muscle"
    case importV8 = "I - Import V8 Performance"
    case supercar = "X - Supercars & Hypercars"
    case electricHybrid = "E - Electric & Hybrid"
    case truck = "T - Truck"

    var id: String { rawValue }

    var code: String {
        switch self {
        case .a_FWD_Tuner: return "A"
        case .performance4Cyl: return "B"
        case .sixCylinderStreet: return "C"
        case .dragTrack: return "D"
        case .highPerformance: return "S"
        case .m_AmericanMuscle: return "M"
        case .importV8: return "I"
        case .supercar: return "X"
        case .electricHybrid: return "E"
        case .truck: return "T"
        }
    }

    var displayName: String {
        switch self {
        case .a_FWD_Tuner: return "FWD Compacts"
        case .performance4Cyl: return "Performance 4-Cylinder"
        case .sixCylinderStreet: return "6-Cylinder Street"
        case .dragTrack: return "Drag & Track Cars"
        case .highPerformance: return "High-Performance Sports Platforms"
        case .m_AmericanMuscle: return "American Muscle"
        case .importV8: return "Import V8 Performance"
        case .supercar: return "Supercars & Hypercars"
        case .electricHybrid: return "Electric & Hybrid"
        case .truck: return "Trucks"
        }
    }

    var factoryDefinition: String {
        switch self {
        case .a_FWD_Tuner:
            return "FWD 4-cylinder compact platforms with strong tuner culture and aftermarket support."
        case .performance4Cyl:
            return "Factory RWD or AWD 4-cylinder platforms designed primarily for performance."
        case .sixCylinderStreet:
            return "Factory 6-cylinder vehicles built as street-focused sedans and coupes, not flagships."
        case .dragTrack:
            return "Purpose-built drag and track cars where quarter-mile performance matters more than the standard class horsepower ladder."
        case .highPerformance:
            return "Factory top-tier performance platforms engineered for speed, handling, and motorsport capability."
        case .m_AmericanMuscle:
            return "Factory American V8 muscle cars with traditional and modern muscle roots."
        case .importV8:
            return "Factory non-American V8 performance vehicles from Europe, Japan, and the UK."
        case .supercar:
            return "Exotic, ultra-high-performance vehicles built as halo or limited-production platforms."
        case .electricHybrid:
            return "Factory electric and hybrid performance platforms."
        case .truck:
            return "Street and performance trucks built around utility platforms, torque-heavy drivetrains, and larger curb weight."
        }
    }

    var includes: String {
        switch self {
        case .a_FWD_Tuner:
            return "Coupes, compact sedans, hatchbacks"
        case .performance4Cyl:
            return "Sports coupes, turbo AWD sedans"
        case .sixCylinderStreet:
            return "Comfort-biased sport sedans and V6 coupes"
        case .dragTrack:
            return "Drag builds, drag-and-drive cars, stripped race builds"
        case .highPerformance:
            return "Performance flagships and advanced AWD platforms"
        case .m_AmericanMuscle:
            return "Traditional and modern muscle"
        case .importV8:
            return "German, Japanese, and British V8s"
        case .supercar:
            return "Supercars, hypercars, limited-production exotics"
        case .electricHybrid:
            return "EVs and performance hybrids"
        case .truck:
            return "Street trucks, sport trucks, high-performance pickups and SUVs"
        }
    }

    var exampleVehicles: String {
        switch self {
        case .a_FWD_Tuner:
            return "Civic Si, RSX, Integra, GTI, Veloster"
        case .performance4Cyl:
            return "BRZ/GR86, WRX, Golf R, Mustang EcoBoost"
        case .sixCylinderStreet:
            return "Charger SXT, Acura TL/TLX V6, BMW 340i, Infiniti Q50"
        case .dragTrack:
            return "Foxbody drag car, tube-chassis import, drag-and-drive build"
        case .highPerformance:
            return "Nissan GT-R, 911, Corvette, Supra 3.0, BMW M"
        case .m_AmericanMuscle:
            return "Mustang GT, GT500, Camaro SS, ZL1, Hellcat"
        case .importV8:
            return "AMG C63, E92 M3, Lexus IS F, Audi RS"
        case .supercar:
            return "Ferrari, Lamborghini, McLaren, Koenigsegg"
        case .electricHybrid:
            return "Tesla Performance, Porsche Taycan, NSX Hybrid"
        case .truck:
            return "TRX, Raptor, Ram SRT-10, Silverado SS"
        }
    }

    var primaryCountries: String {
        switch self {
        case .a_FWD_Tuner:
            return "Japan, Germany, Korea"
        case .performance4Cyl:
            return "Japan, Germany, USA"
        case .sixCylinderStreet:
            return "USA, Japan, Germany"
        case .dragTrack:
            return "Global"
        case .highPerformance:
            return "Global"
        case .m_AmericanMuscle:
            return "USA"
        case .importV8:
            return "Germany, Japan, UK"
        case .supercar:
            return "Italy, UK, Sweden"
        case .electricHybrid:
            return "Global"
        case .truck:
            return "USA, Japan, Global"
        }
    }

    var accentColor: Color {
        switch self {
        case .a_FWD_Tuner: return Color("EmpireMint")
        case .performance4Cyl: return Color(red: 0.95, green: 0.78, blue: 0.12)
        case .sixCylinderStreet: return Color(red: 0.45, green: 0.72, blue: 1.0)
        case .dragTrack: return Color(red: 1.0, green: 0.42, blue: 0.32)
        case .highPerformance: return Color(red: 0.98, green: 0.45, blue: 0.20)
        case .m_AmericanMuscle: return Color(red: 0.94, green: 0.24, blue: 0.24)
        case .importV8: return Color(red: 0.72, green: 0.48, blue: 1.0)
        case .supercar: return Color(red: 1.0, green: 0.86, blue: 0.34)
        case .electricHybrid: return Color(red: 0.30, green: 0.92, blue: 0.86)
        case .truck: return Color(red: 0.70, green: 0.86, blue: 0.42)
        }
    }

    var stageBands: [StageBand] {
        switch self {
        case .a_FWD_Tuner:
            return [
                StageBand(rank: .stage1, lowerBound: 180, upperBound: 220),
                StageBand(rank: .stage2, lowerBound: 221, upperBound: 300),
                StageBand(rank: .stage3, lowerBound: 301, upperBound: 450),
                StageBand(rank: .stage4, lowerBound: 451, upperBound: 600),
                StageBand(rank: .stage5, lowerBound: 601, upperBound: 800),
                StageBand(rank: .maxOut, lowerBound: 801, upperBound: nil)
            ]
        case .performance4Cyl:
            return [
                StageBand(rank: .stage1, lowerBound: 220, upperBound: 280),
                StageBand(rank: .stage2, lowerBound: 281, upperBound: 360),
                StageBand(rank: .stage3, lowerBound: 361, upperBound: 500),
                StageBand(rank: .stage4, lowerBound: 501, upperBound: 600),
                StageBand(rank: .stage5, lowerBound: 601, upperBound: 800),
                StageBand(rank: .maxOut, lowerBound: 801, upperBound: nil)
            ]
        case .sixCylinderStreet:
            return [
                StageBand(rank: .stage1, lowerBound: 280, upperBound: 350),
                StageBand(rank: .stage2, lowerBound: 351, upperBound: 450),
                StageBand(rank: .stage3, lowerBound: 451, upperBound: 550),
                StageBand(rank: .stage4, lowerBound: 551, upperBound: 700),
                StageBand(rank: .stage5, lowerBound: 701, upperBound: 850),
                StageBand(rank: .maxOut, lowerBound: 851, upperBound: nil)
            ]
        case .dragTrack:
            return []
        case .highPerformance:
            return [
                StageBand(rank: .stage1, lowerBound: 350, upperBound: 450),
                StageBand(rank: .stage2, lowerBound: 451, upperBound: 575),
                StageBand(rank: .stage3, lowerBound: 576, upperBound: 700),
                StageBand(rank: .stage4, lowerBound: 701, upperBound: 900),
                StageBand(rank: .stage5, lowerBound: 901, upperBound: 1100),
                StageBand(rank: .maxOut, lowerBound: 1101, upperBound: nil)
            ]
        case .m_AmericanMuscle:
            return [
                StageBand(rank: .stage1, lowerBound: 300, upperBound: 380),
                StageBand(rank: .stage2, lowerBound: 381, upperBound: 500),
                StageBand(rank: .stage3, lowerBound: 501, upperBound: 650),
                StageBand(rank: .stage4, lowerBound: 651, upperBound: 800),
                StageBand(rank: .stage5, lowerBound: 801, upperBound: 1000),
                StageBand(rank: .maxOut, lowerBound: 1001, upperBound: nil)
            ]
        case .importV8:
            return [
                StageBand(rank: .stage1, lowerBound: 320, upperBound: 400),
                StageBand(rank: .stage2, lowerBound: 401, upperBound: 520),
                StageBand(rank: .stage3, lowerBound: 521, upperBound: 680),
                StageBand(rank: .stage4, lowerBound: 681, upperBound: 850),
                StageBand(rank: .stage5, lowerBound: 851, upperBound: 1050),
                StageBand(rank: .maxOut, lowerBound: 1051, upperBound: nil)
            ]
        case .supercar:
            return [
                StageBand(rank: .stage1, lowerBound: 500, upperBound: 650),
                StageBand(rank: .stage2, lowerBound: 651, upperBound: 800),
                StageBand(rank: .stage3, lowerBound: 801, upperBound: 1000),
                StageBand(rank: .stage4, lowerBound: 1001, upperBound: 1250),
                StageBand(rank: .stage5, lowerBound: 1251, upperBound: 1500),
                StageBand(rank: .maxOut, lowerBound: 1501, upperBound: nil)
            ]
        case .electricHybrid:
            return []
        case .truck:
            return [
                StageBand(rank: .stage1, lowerBound: 300, upperBound: 420),
                StageBand(rank: .stage2, lowerBound: 421, upperBound: 550),
                StageBand(rank: .stage3, lowerBound: 551, upperBound: 700),
                StageBand(rank: .stage4, lowerBound: 701, upperBound: 900),
                StageBand(rank: .stage5, lowerBound: 901, upperBound: 1100),
                StageBand(rank: .maxOut, lowerBound: 1101, upperBound: nil)
            ]
        }
    }

    static func from(rawValue: String?) -> VehicleClass? {
        guard let rawValue else { return nil }
        return VehicleClass(rawValue: rawValue)
            ?? (rawValue == "T - Track-Only" ? .truck : nil)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let decoded = VehicleClass.from(rawValue: rawValue) {
            self = decoded
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid vehicle class value: \(rawValue)")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum StageSystem {
    static let requiredMajorModCount = 3
    static let tuneKeywords = ["tune", "ecu", "flash", "map"]
    static let majorModKeywords = [
        "tune",
        "intake",
        "intake manifold",
        "headers",
        "performance exhaust",
        "exhaust",
        "forced induction",
        "turbo",
        "supercharger",
        "motor swap",
        "drivetrain swap",
        "transmission upgrade",
        "transmission upgrades",
        "built motor"
    ]

    static func displayLabel(for stage: Int, isJailbreak: Bool) -> String {
        if isJailbreak { return "Jailbreak" }
        return BuildStageRank.from(rawStage: stage).label
    }

    static func accentColor(for stage: Int, isJailbreak: Bool) -> Color {
        if isJailbreak { return .purple }
        return BuildStageRank.from(rawStage: stage).accentColor
    }

    static func assessment(vehicleClass: VehicleClass?, horsepower: Int, selectedMajorMods: [String]) -> StageAssessment {
        let normalized = selectedMajorMods.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let majorModCount = normalized.count
        let hasTune = normalized.contains { title in
            tuneKeywords.contains { title.contains($0) }
        }

        guard let vehicleClass else {
            return StageAssessment(
                stage: .stock,
                isJailbreak: false,
                summary: "Pick a class to unlock stage classification.",
                detail: "Stages are class-relative now. Select a vehicle class so the horsepower can be mapped against the proper class ladder.",
                majorModCount: majorModCount,
                hasTune: hasTune
            )
        }

        if vehicleClass == .electricHybrid {
            return StageAssessment(
                stage: .stock,
                isJailbreak: true,
                summary: "Class E is treated as Jailbreak.",
                detail: "Electric and hybrid performance builds bypass the standard Stage 1-5 and MAX ladder in the new system.",
                majorModCount: majorModCount,
                hasTune: hasTune
            )
        }

        if vehicleClass == .dragTrack {
            return StageAssessment(
                stage: .stock,
                isJailbreak: false,
                summary: "Class D uses quarter-mile results.",
                detail: "Drag and track cars are scored by fastest recorded 1/4 mile, not the standard Stage 1-5 horsepower ladder.",
                majorModCount: majorModCount,
                hasTune: hasTune
            )
        }

        guard hasTune, majorModCount >= requiredMajorModCount else {
            return StageAssessment(
                stage: .stock,
                isJailbreak: false,
                summary: "This build is still Stock.",
                detail: "A car remains Stock until at least \(requiredMajorModCount) major mods including a tune are present. Current setup: \(majorModCount) major mod\(majorModCount == 1 ? "" : "s")\(hasTune ? " with a tune." : " and no tune detected.")",
                majorModCount: majorModCount,
                hasTune: hasTune
            )
        }

        let stageBands = vehicleClass.stageBands
        if let firstBand = stageBands.first, horsepower < firstBand.lowerBound {
            return StageAssessment(
                stage: .stock,
                isJailbreak: false,
                summary: "This build is below the Class \(vehicleClass.code) stage range.",
                detail: "\(horsepower) HP does not yet reach the \(firstBand.rank.label) threshold of \(firstBand.lowerBound) HP for Class \(vehicleClass.code).",
                majorModCount: majorModCount,
                hasTune: true
            )
        }

        let matchedStage = stageBands.first(where: { band in
            horsepower >= band.lowerBound && (band.upperBound.map { horsepower <= $0 } ?? true)
        })?.rank ?? .maxOut

        return StageAssessment(
            stage: matchedStage,
            isJailbreak: false,
            summary: "\(matchedStage.label) \(vehicleClass.code) build identified.",
            detail: "\(horsepower) HP lands in the \(matchedStage.label) band for Class \(vehicleClass.code) once the build clears the major-mod gate.",
            majorModCount: majorModCount,
            hasTune: true
        )
    }

    static func isMajorMod(_ title: String, isMajorFlag: Bool = false) -> Bool {
        if isMajorFlag { return true }
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return majorModKeywords.contains { normalized.contains($0) }
    }
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
