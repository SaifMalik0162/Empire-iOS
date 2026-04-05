import Foundation
import Supabase
import UIKit
import OSLog

struct SBCarRow: Codable, Equatable {
    let id: String
    let user_id: String
    let name: String
    let car_description: String
    let make: String?
    let model: String?
    let image_name: String
    let photo_file_name: String?
    let photo_path: String?
    let horsepower: Int
    let stage: Int
    let is_jailbreak: Bool
    let vehicle_class: String?
    let build_category: String?
}

struct SBSpecRow: Codable, Equatable {
    let id: String
    let car_id: String
    let key: String
    let value: String
}

struct SBModRow: Codable, Equatable {
    let id: String
    let car_id: String
    let title: String
    let notes: String
    let is_major: Bool
}

final class SupabaseCarsService {
    private var client: SupabaseClient { SupabaseClientProvider.shared }
    private let photosBucket = "car-photos"
    private let logger = AppLogger.supabaseCars

    private func authenticatedUserId() async throws -> String {
        let user = try await client.auth.user()
        return user.id.uuidString.lowercased()
    }

    // Fetch all cars for a user and stitch specs/mods
    func fetchCars(for userId: String) async throws -> [Car] {
        let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1) Fetch car rows
        let carRows: [SBCarRow] = try await client
            .from("cars")
            .select()
            .eq("user_id", value: normalizedUserId)
            .execute()
            .value

        if carRows.isEmpty { return [] }

        let carIds = carRows.map { $0.id }
        let carUUIDs = carIds.compactMap(UUID.init(uuidString:))

        // 2) Fetch specs for these cars
        let specRows: [SBSpecRow]
        if carUUIDs.count == carIds.count, !carUUIDs.isEmpty {
            specRows = try await client
                .from("spec_items")
                .select()
                .in("car_id", values: carUUIDs)
                .execute()
                .value
        } else {
            specRows = try await client
                .from("spec_items")
                .select()
                .in("car_id", values: carIds)
                .execute()
                .value
        }

        // 3) Fetch mods for these cars
        let modRows: [SBModRow]
        if carUUIDs.count == carIds.count, !carUUIDs.isEmpty {
            modRows = try await client
                .from("mod_items")
                .select()
                .in("car_id", values: carUUIDs)
                .execute()
                .value
        } else {
            modRows = try await client
                .from("mod_items")
                .select()
                .in("car_id", values: carIds)
                .execute()
                .value
        }

        // 4) Group specs/mods by car_id
        let specsByCar = Dictionary(grouping: specRows, by: { $0.car_id })
        let modsByCar = Dictionary(grouping: modRows, by: { $0.car_id })

        // 5) Map to domain Car
        var cars: [Car] = []
        cars.reserveCapacity(carRows.count)

        for row in carRows {
            let specs: [SpecItem] = (specsByCar[row.id] ?? []).map { s in
                SpecItem(id: UUID(uuidString: s.id) ?? UUID(), key: s.key, value: s.value)
            }
            let mods: [ModItem] = (modsByCar[row.id] ?? []).map { m in
                ModItem(id: UUID(uuidString: m.id) ?? UUID(), title: m.title, notes: m.notes, isMajor: m.is_major)
            }

            let localPhotoFileName = await cachedPhotoFileName(for: row)

            let car = Car(
                id: UUID(uuidString: row.id) ?? UUID(),
                name: row.name,
                description: row.car_description,
                make: row.make,
                model: row.model,
                imageName: row.image_name,
                photoFileName: localPhotoFileName,
                horsepower: row.horsepower,
                stage: row.stage,
                specs: specs,
                mods: mods,
                isJailbreak: row.is_jailbreak,
                vehicleClass: VehicleClass.from(rawValue: row.vehicle_class),
                buildCategory: BuildCategory.from(rawValue: row.build_category)
            )
            cars.append(car)
        }
        return cars
    }

    func fetchCarsBundle(for userId: String) async throws -> [Car] {
        try await fetchCars(for: userId)
    }

    // Push a single car (upsert) along with specs/mods
    func upsertCarBundle(_ car: Car, userId: String) async throws {
        let authenticatedUserId = try await authenticatedUserId()
        let remotePhotoPath: String?
        do {
            remotePhotoPath = try await syncPhotoIfNeeded(car: car, userId: authenticatedUserId)
        } catch {
            remotePhotoPath = try await fetchCurrentPhotoPath(carId: car.id.uuidString, userId: authenticatedUserId)
            logger.warning("Photo sync failed for car \(car.id.uuidString, privacy: .public); continuing car upsert. Error: \(String(describing: error), privacy: .public)")
        }

        // Upsert car
        let carRow = SBCarRow(
            id: car.id.uuidString,
            user_id: authenticatedUserId,
            name: car.name,
            car_description: car.description,
            make: car.make,
            model: car.model,
            image_name: car.imageName,
            photo_file_name: car.photoFileName,
            photo_path: remotePhotoPath,
            horsepower: car.horsepower,
            stage: car.stage,
            is_jailbreak: car.isJailbreak,
            vehicle_class: car.vehicleClass?.rawValue,
            build_category: car.buildCategory?.rawValue
        )
        _ = try await client.from("cars").upsert(carRow, onConflict: "id").execute()

        // Replace specs for this car
        _ = try await client.from("spec_items").delete().eq("car_id", value: car.id.uuidString).execute()
        if !car.specs.isEmpty {
            let specRows = car.specs.map { s in
                SBSpecRow(id: s.id.uuidString, car_id: car.id.uuidString, key: s.key, value: s.value)
            }
            _ = try await client.from("spec_items").insert(specRows).execute()
        }

        // Replace mods for this car
        _ = try await client.from("mod_items").delete().eq("car_id", value: car.id.uuidString).execute()
        if !car.mods.isEmpty {
            let modRows = car.mods.map { m in
                SBModRow(id: m.id.uuidString, car_id: car.id.uuidString, title: m.title, notes: m.notes, is_major: m.isMajor)
            }
            _ = try await client.from("mod_items").insert(modRows).execute()
        }
    }

    func deleteCar(id: String) async throws {
        let authenticatedUserId = try await authenticatedUserId()
        let remotePath = "\(authenticatedUserId)/\(id).jpg"
        _ = try? await client.storage.from(photosBucket).remove(paths: [remotePath])
        _ = try await client
            .from("cars")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: authenticatedUserId)
            .execute()
    }

    private func syncPhotoIfNeeded(car: Car, userId: String) async throws -> String? {
        let normalizedUserId = userId.lowercased()
        guard let localFileName = car.photoFileName else {
            return nil
        }

        guard let localData = loadLocalImageData(fileName: localFileName) else {
            return try await fetchCurrentPhotoPath(carId: car.id.uuidString, userId: normalizedUserId)
        }

        let compressed = optimizedImageData(
            from: localData,
            maxPixelSize: 1400,
            maxBytes: 500_000,
            compressionFloor: 0.5
        ) ?? localData
        let remotePath = "\(normalizedUserId)/\(car.id.uuidString).jpg"

        try await client.storage
            .from(photosBucket)
            .upload(
                remotePath,
                data: compressed,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        return remotePath
    }

    private func fetchCurrentPhotoPath(carId: String, userId: String) async throws -> String? {
        struct PhotoPathRow: Codable {
            let photo_path: String?
        }

        let rows: [PhotoPathRow] = try await client
            .from("cars")
            .select("photo_path")
            .eq("id", value: carId)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        return rows.first?.photo_path
    }

    private func cachedPhotoFileName(for row: SBCarRow) async -> String? {
        if let localName = row.photo_file_name,
           loadLocalImageData(fileName: localName) != nil {
            return localName
        }

        guard let remotePath = row.photo_path else {
            return row.photo_file_name
        }

        do {
            let data = try await client.storage.from(photosBucket).download(path: remotePath)
            let localName = row.photo_file_name ?? "car_\(row.id).jpg"
            try saveLocalImageData(data, fileName: localName)
            return localName
        } catch {
            return row.photo_file_name
        }
    }

    private func documentsDirectoryURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private func loadLocalImageData(fileName: String) -> Data? {
        guard let documentsURL = documentsDirectoryURL() else { return nil }
        let url = documentsURL.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    private func saveLocalImageData(_ data: Data, fileName: String) throws {
        guard let documentsURL = documentsDirectoryURL() else { return }
        let url = documentsURL.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])
    }

    private func compressImageData(_ data: Data, maxBytes: Int) -> Data? {
        guard data.count > maxBytes else { return data }
        guard let image = UIImage(data: data) else { return data }

        var compression: CGFloat = 0.92
        var result = image.jpegData(compressionQuality: compression)

        while let current = result, current.count > maxBytes, compression > 0.45 {
            compression -= 0.08
            result = image.jpegData(compressionQuality: compression)
        }

        return result ?? data
    }

    private func optimizedImageData(
        from data: Data,
        maxPixelSize: CGFloat,
        maxBytes: Int,
        compressionFloor: CGFloat
    ) -> Data? {
        guard let image = UIImage(data: data) else { return data }

        let resizedImage = resizedImageIfNeeded(image, maxPixelSize: maxPixelSize)
        var compression: CGFloat = 0.8
        var result = resizedImage.jpegData(compressionQuality: compression)

        while let current = result, current.count > maxBytes, compression > compressionFloor {
            compression -= 0.07
            result = resizedImage.jpegData(compressionQuality: compression)
        }

        return result ?? data
    }

    private func resizedImageIfNeeded(_ image: UIImage, maxPixelSize: CGFloat) -> UIImage {
        let size = image.size
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxPixelSize, longestEdge > 0 else { return image }

        let scale = maxPixelSize / longestEdge
        let targetSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
