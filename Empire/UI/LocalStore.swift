import Foundation
import SwiftUI
import SwiftData

// MARK: - SwiftData Models

@Model
final class CarEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var carDescription: String
    var imageName: String
    var photoFileName: String?
    var horsepower: Int
    var stage: Int
    var isJailbreak: Bool
    var vehicleClassRaw: String?
    var userKey: String

    @Relationship(deleteRule: .cascade) var specs: [SpecItemEntity]
    @Relationship(deleteRule: .cascade) var mods: [ModItemEntity]

    init(id: UUID = UUID(),
         name: String,
         carDescription: String,
         imageName: String,
         photoFileName: String? = nil,
         horsepower: Int,
         stage: Int,
         isJailbreak: Bool = false,
         vehicleClassRaw: String? = nil,
         userKey: String,
         specs: [SpecItemEntity] = [],
         mods: [ModItemEntity] = []) {
        self.id = id
        self.name = name
        self.carDescription = carDescription
        self.imageName = imageName
        self.photoFileName = photoFileName
        self.horsepower = horsepower
        self.stage = stage
        self.isJailbreak = isJailbreak
        self.vehicleClassRaw = vehicleClassRaw
        self.userKey = userKey
        self.specs = specs
        self.mods = mods
    }
}

@Model
final class SpecItemEntity {
    @Attribute(.unique) var id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

@Model
final class ModItemEntity {
    @Attribute(.unique) var id: UUID
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

@Model
final class MerchItemEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var priceString: String
    var imageName: String
    var categoryRaw: String
    var lastUpdated: Date?

    init(id: UUID = UUID(), name: String, priceString: String, imageName: String, categoryRaw: String, lastUpdated: Date? = nil) {
        self.id = id
        self.name = name
        self.priceString = priceString
        self.imageName = imageName
        self.categoryRaw = categoryRaw
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Mapping helpers between domain structs and SwiftData models

extension CarEntity {
    func toDomain() -> Car {
        let specsDomain: [SpecItem] = specs.map { SpecItem(id: $0.id, key: $0.key, value: $0.value) }
        let modsDomain: [ModItem] = mods.map { ModItem(id: $0.id, title: $0.title, notes: $0.notes, isMajor: $0.isMajor) }
        let vehicleClass: VehicleClass? = vehicleClassRaw.flatMap { VehicleClass(rawValue: $0) }
        return Car(
            id: id,
            name: name,
            description: carDescription,
            imageName: imageName,
            photoFileName: photoFileName,
            horsepower: horsepower,
            stage: stage,
            specs: specsDomain,
            mods: modsDomain,
            isJailbreak: isJailbreak,
            vehicleClass: vehicleClass
        )
    }

    static func fromDomain(_ car: Car, userKey: String) -> CarEntity {
        let specEntities = car.specs.map { SpecItemEntity(id: $0.id, key: $0.key, value: $0.value) }
        let modEntities = car.mods.map { ModItemEntity(id: $0.id, title: $0.title, notes: $0.notes, isMajor: $0.isMajor) }
        return CarEntity(
            id: car.id,
            name: car.name,
            carDescription: car.description,
            imageName: car.imageName,
            photoFileName: car.photoFileName,
            horsepower: car.horsepower,
            stage: car.stage,
            isJailbreak: car.isJailbreak,
            vehicleClassRaw: car.vehicleClass?.rawValue,
            userKey: userKey,
            specs: specEntities,
            mods: modEntities
        )
    }

    func update(from car: Car, userKey: String) {
        self.name = car.name
        self.carDescription = car.description
        self.imageName = car.imageName
        self.photoFileName = car.photoFileName
        self.horsepower = car.horsepower
        self.stage = car.stage
        self.isJailbreak = car.isJailbreak
        self.vehicleClassRaw = car.vehicleClass?.rawValue
        self.userKey = userKey
        // Replace specs/mods to keep it simple in 
        self.specs = car.specs.map { SpecItemEntity(id: $0.id, key: $0.key, value: $0.value) }
        self.mods = car.mods.map { ModItemEntity(id: $0.id, title: $0.title, notes: $0.notes, isMajor: $0.isMajor) }
    }
}

extension MerchItemEntity {
    func toDomain() -> MerchItem {
        let category = MerchCategory(rawValue: categoryRaw) ?? .apparel
        return MerchItem(name: name, price: priceString, imageName: imageName, category: category)
    }

    static func fromDomain(_ item: MerchItem) -> MerchItemEntity {
        MerchItemEntity(id: item.id, name: item.name, priceString: item.price, imageName: item.imageName, categoryRaw: item.category.rawValue, lastUpdated: Date())
    }

    func update(from item: MerchItem) {
        self.name = item.name
        self.priceString = item.price
        self.imageName = item.imageName
        self.categoryRaw = item.category.rawValue
        self.lastUpdated = Date()
    }
}

// MARK: - LocalStore facade

enum LocalStoreError: Error {
    case missingContext
}

@MainActor
final class LocalStore {
    static let shared = LocalStore()
    private init() {}

    // MARK: Vehicles

    func fetchCars(context: ModelContext, userKey: String) -> [Car] {
        let descriptor = FetchDescriptor<CarEntity>(predicate: #Predicate { $0.userKey == userKey })
        do {
            let entities = try context.fetch(descriptor)
            return entities.map { $0.toDomain() }
        } catch {
            print("[LocalStore] fetchCars error: \(error)")
            return []
        }
    }

    func upsertCar(_ car: Car, context: ModelContext, userKey: String) {
        let descriptor = FetchDescriptor<CarEntity>(predicate: #Predicate { $0.id == car.id && $0.userKey == userKey })
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.update(from: car, userKey: userKey)
            } else {
                let entity = CarEntity.fromDomain(car, userKey: userKey)
                context.insert(entity)
            }
            try context.save()
        } catch {
            print("[LocalStore] upsertCar error: \(error)")
        }
    }

    func replaceAllCars(_ cars: [Car], context: ModelContext, userKey: String) {
        // Delete all existing for this userKey, then insert all
        let descriptor = FetchDescriptor<CarEntity>(predicate: #Predicate { $0.userKey == userKey })
        do {
            let existing = try context.fetch(descriptor)
            for e in existing { context.delete(e) }
            for c in cars { context.insert(CarEntity.fromDomain(c, userKey: userKey)) }
            try context.save()
        } catch {
            print("[LocalStore] replaceAllCars error: \(error)")
        }
    }

    // Migration from existing UserDefaults store used by UserVehiclesViewModel
    func migrateFromUserDefaultsIfNeeded(context: ModelContext, userKey: String) {
        let descriptor = FetchDescriptor<CarEntity>(predicate: #Predicate { $0.userKey == userKey })
        do {
            let existing = try context.fetch(descriptor)
            if !existing.isEmpty { return }
        } catch {
            // If fetch failed, try migration anyway
        }
        let vehiclesKey = "saved_user_vehicles_\(userKey)"
        if let data = UserDefaults.standard.data(forKey: vehiclesKey),
           let decoded = try? JSONDecoder().decode([Car].self, from: data) {
            replaceAllCars(decoded, context: context, userKey: userKey)
            // Clear the old store to avoid re-importing
            UserDefaults.standard.removeObject(forKey: vehiclesKey)
            print("[LocalStore] Migrated \(decoded.count) vehicles from UserDefaults for userKey=\(userKey)")
        }
    }

    // MARK: Merch caching

    func fetchMerch(context: ModelContext) -> [MerchItem] {
        let descriptor = FetchDescriptor<MerchItemEntity>()
        do {
            let entities = try context.fetch(descriptor)
            return entities.map { $0.toDomain() }
        } catch {
            print("[LocalStore] fetchMerch error: \(error)")
            return []
        }
    }

    func cacheMerch(_ items: [MerchItem], context: ModelContext) {
        // Replace all cached merch for now; in the future, we can diff/merge by id
        let descriptor = FetchDescriptor<MerchItemEntity>()
        do {
            let existing = try context.fetch(descriptor)
            for e in existing { context.delete(e) }
            for item in items { context.insert(MerchItemEntity.fromDomain(item)) }
            try context.save()
        } catch {
            print("[LocalStore] cacheMerch error: \(error)")
        }
    }
}
