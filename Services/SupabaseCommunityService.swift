import Foundation
import Supabase
import UIKit
import OSLog

// MARK: - Domain model

struct CommunityPost: Identifiable, Equatable {
    let id: UUID
    let userId: String
    let carId: UUID?
    let caption: String?
    let photoPath: String?
    let make: String?
    let model: String?
    let carName: String
    let horsepower: Int
    let stage: Int
    let isJailbreak: Bool
    let vehicleClass: String?
    var likesCount: Int
    let createdAt: Date

    var username: String?
    var avatarPath: String?

    var isLiked: Bool = false
}

// MARK: - Supabase row shapes

private struct SBCommunityPostRow: Codable {
    let id: String
    let user_id: String
    let car_id: String?
    let caption: String?
    let photo_path: String?
    let make: String?
    let model: String?
    let car_name: String
    let horsepower: Int
    let stage: Int
    let is_jailbreak: Bool
    let vehicle_class: String?
    let likes_count: Int
    let created_at: String
}

private struct SBInsertPost: Encodable {
    let user_id: String
    let car_id: String?
    let caption: String?
    let photo_path: String?
    let make: String?
    let model: String?
    let car_name: String
    let horsepower: Int
    let stage: Int
    let is_jailbreak: Bool
    let vehicle_class: String?
}

private struct SBLikeRow: Codable {
    let post_id: String
    let user_id: String
}

private struct SBProfileRow: Codable {
    let id: String
    let username: String?
    let avatar_path: String?
}

// MARK: - Service

final class SupabaseCommunityService {
    private let client = SupabaseClientProvider.client
    private let photosBucket = "car-photos"
    private let logger = Logger(subsystem: "com.empire.app", category: "community")

    private let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoBasic = ISO8601DateFormatter()

    // MARK: Fetch feed

    /// Fetches the most recent posts (latest first). Enriches with profile info and like state for currentUserId.
    func fetchFeed(currentUserId: String, limit: Int = 40, offset: Int = 0) async throws -> [CommunityPost] {
        let rows: [SBCommunityPostRow] = try await client
            .from("community_posts")
            .select()
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        // Fetch liked post IDs for current user
        let postIds = rows.map { $0.id }
        let likedIds: Set<String>
        do {
            let likes: [SBLikeRow] = try await client
                .from("post_likes")
                .select("post_id, user_id")
                .eq("user_id", value: currentUserId)
                .in("post_id", values: postIds)
                .execute()
                .value
            likedIds = Set(likes.map { $0.post_id })
        } catch {
            logger.warning("Could not fetch liked IDs: \(String(describing: error), privacy: .public)")
            likedIds = []
        }

        // Fetch profiles for all poster user IDs
        let userIds = Array(Set(rows.map { $0.user_id }))
        let profilesByUserId: [String: SBProfileRow]
        do {
            let profiles: [SBProfileRow] = try await client
                .from("profiles")
                .select("id, username, avatar_path")
                .in("id", values: userIds)
                .execute()
                .value
            profilesByUserId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        } catch {
            logger.warning("Could not fetch profiles: \(String(describing: error), privacy: .public)")
            profilesByUserId = [:]
        }

        return rows.compactMap { row -> CommunityPost? in
            guard let date = parseDate(row.created_at) else { return nil }
            let profile = profilesByUserId[row.user_id]
            var post = CommunityPost(
                id: UUID(uuidString: row.id) ?? UUID(),
                userId: row.user_id,
                carId: row.car_id.flatMap { UUID(uuidString: $0) },
                caption: row.caption,
                photoPath: row.photo_path,
                make: row.make,
                model: row.model,
                carName: row.car_name,
                horsepower: row.horsepower,
                stage: row.stage,
                isJailbreak: row.is_jailbreak,
                vehicleClass: row.vehicle_class,
                likesCount: row.likes_count,
                createdAt: date,
                username: profile?.username,
                avatarPath: profile?.avatar_path
            )
            post.isLiked = likedIds.contains(row.id)
            return post
        }
    }

    // MARK: Share post

    /// Shares a car to the community feed. Uploads photo if photoData provided.
    func sharePost(car: Car, caption: String?, currentUserId: String, photoData: Data?) async throws -> CommunityPost {
        var photoPath: String? = nil

        // Upload photo to Supabase Storage if provided
        if let data = photoData {
            let compressed = compressImageData(data, maxBytes: 900_000) ?? data
            let path = "\(currentUserId.lowercased())/community_\(UUID().uuidString).jpg"
            do {
                try await client.storage
                    .from(photosBucket)
                    .upload(path, data: compressed, options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: false
                    ))
                photoPath = path
                logger.info("✅ Photo uploaded to: \(path, privacy: .public)")
            } catch {
                logger.error("🔴 Photo upload failed: \(String(describing: error), privacy: .public)")
                print("🔴 Photo upload failed: \(error)")
                // Continue without photo rather than failing the whole post
            }
        }

        // Fall back to existing car photo path if no new upload
        if photoPath == nil, let existingFileName = car.photoFileName {
            let existing = "\(currentUserId.lowercased())/\(car.id.uuidString).jpg"
            photoPath = existing
            _ = existingFileName // suppress unused warning
        }

        let insert = SBInsertPost(
            user_id: currentUserId,
            car_id: car.id.uuidString,
            caption: caption?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : caption?.trimmingCharacters(in: .whitespacesAndNewlines),
            photo_path: photoPath,
            make: car.make,
            model: car.model,
            car_name: car.name,
            horsepower: car.horsepower,
            stage: car.stage,
            is_jailbreak: car.isJailbreak,
            vehicle_class: car.vehicleClass?.rawValue
        )

        let rows: [SBCommunityPostRow] = try await client
            .from("community_posts")
            .insert(insert)
            .select()
            .execute()
            .value

        guard let row = rows.first, let date = parseDate(row.created_at) else {
            throw NSError(domain: "CommunityService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Post created but could not read back row."])
        }

        return CommunityPost(
            id: UUID(uuidString: row.id) ?? UUID(),
            userId: row.user_id,
            carId: UUID(uuidString: row.car_id ?? ""),
            caption: row.caption,
            photoPath: row.photo_path,
            make: row.make,
            model: row.model,
            carName: row.car_name,
            horsepower: row.horsepower,
            stage: row.stage,
            isJailbreak: row.is_jailbreak,
            vehicleClass: row.vehicle_class,
            likesCount: 0,
            createdAt: date
        )
    }

    // MARK: Like / Unlike

    func likePost(postId: UUID, userId: String) async throws {
        let row = SBLikeRow(post_id: postId.uuidString, user_id: userId)
        _ = try await client
            .from("post_likes")
            .upsert(row, onConflict: "post_id, user_id")
            .execute()
    }

    func unlikePost(postId: UUID, userId: String) async throws {
        _ = try await client
            .from("post_likes")
            .delete()
            .eq("post_id", value: postId.uuidString)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: Delete

    func deletePost(postId: UUID) async throws {
        _ = try await client
            .from("community_posts")
            .delete()
            .eq("id", value: postId.uuidString)
            .execute()
    }

    // MARK: Public URL

    func publicURL(for path: String) -> URL? {
        // Do NOT percent-encode the path — Supabase Storage URLs use raw paths
        // including the "/" separator between userId and filename.
        // Encoding it turns "user/file.jpg" into "user%2Ffile.jpg" which 404s.
        let base = SupabaseConfig.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/storage/v1/object/public/\(photosBucket)/\(path)")
    }

    // MARK: Private helpers

    private func parseDate(_ value: String) -> Date? {
        isoFull.date(from: value) ?? isoBasic.date(from: value)
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
}
