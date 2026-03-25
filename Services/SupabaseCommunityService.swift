import Foundation
import Supabase
import UIKit

// MARK: - Domain models

struct CommunityPost: Identifiable, Equatable {
    let id: UUID
    let userId: String
    let carId: UUID?
    let caption: String?
    let photoPath: String?
    let photoPaths: [String]
    let make: String?
    let model: String?
    let carName: String
    let horsepower: Int
    let stage: Int
    let isJailbreak: Bool
    let vehicleClass: String?
    var likesCount: Int
    var commentsCount: Int
    let createdAt: Date

    var username: String?
    var avatarPath: String?

    var isLiked: Bool = false
}

struct PostComment: Identifiable, Equatable {
    let id: UUID
    let postId: UUID
    let userId: String
    let body: String
    let createdAt: Date

    var username: String?
    var avatarPath: String?
}

// MARK: - Supabase row shapes

private struct SBCommunityPostRow: Codable {
    let id: String
    let user_id: String
    let car_id: String?
    let caption: String?
    let photo_path: String?
    let photo_paths: [String]?
    let make: String?
    let model: String?
    let car_name: String
    let horsepower: Int
    let stage: Int
    let is_jailbreak: Bool
    let vehicle_class: String?
    let likes_count: Int
    let comments_count: Int?
    let created_at: String
}

private struct SBInsertPost: Encodable {
    let user_id: String
    let car_id: String?
    let caption: String?
    let photo_path: String?
    let photo_paths: [String]?
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

private struct SBLikeInsert: Encodable {
    let post_id: UUID
    let user_id: UUID
}

private struct SBProfileRow: Codable {
    let id: String
    let username: String?
    let avatar_path: String?
}

private struct SBCommentRow: Codable {
    let id: String
    let post_id: String
    let user_id: String
    let body: String
    let created_at: String
}

private struct SBInsertComment: Encodable {
    let post_id: String
    let user_id: String
    let body: String
}

private struct SBInsertCommentUUID: Encodable {
    let post_id: UUID
    let user_id: UUID
    let body: String
}

private struct SBCommentCountRow: Codable {
    let post_id: String
}

// MARK: - Service

final class SupabaseCommunityService {
    private var client: SupabaseClient { SupabaseClientProvider.client }
    private let photosBucket = "car-photos"
    private let avatarsBucket = "avatars"

    private let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoBasic = ISO8601DateFormatter()

    // MARK: - Fetch feed

    func fetchFeed(
        currentUserId: String,
        limit: Int = 40,
        offset: Int = 0,
        authorUserId: String? = nil
    ) async throws -> [CommunityPost] {
        let baseQuery = client
            .from("community_posts")
            .select()
        let filteredQuery = if let authorUserId, !authorUserId.isEmpty {
            if let authorUUID = UUID(uuidString: authorUserId) {
                baseQuery.eq("user_id", value: authorUUID)
            } else {
                baseQuery.eq("user_id", value: authorUserId)
            }
        } else {
            baseQuery
        }

        let rows: [SBCommunityPostRow] = try await filteredQuery
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        let postIds = rows.map { $0.id }
        let postUUIDs = postIds.compactMap(UUID.init(uuidString:))

        // Liked post IDs for current user
        let likedIds: Set<String>
        do {
            let likes: [SBLikeRow]
            if let userUUID = UUID(uuidString: currentUserId) {
                likes = try await client
                    .from("post_likes")
                    .select("post_id, user_id")
                    .eq("user_id", value: userUUID)
                    .in("post_id", values: postUUIDs)
                    .execute()
                    .value
            } else {
                likes = try await client
                    .from("post_likes")
                    .select("post_id, user_id")
                    .eq("user_id", value: currentUserId)
                    .in("post_id", values: postIds)
                    .execute()
                    .value
            }
            likedIds = Set(likes.map { $0.post_id })
        } catch {
            likedIds = []
        }

        let commentsByPostId: [String: Int]
        do {
            let commentRows: [SBCommentCountRow]
            if postUUIDs.count == postIds.count, !postUUIDs.isEmpty {
                commentRows = try await client
                    .from("post_comments")
                    .select("post_id")
                    .in("post_id", values: postUUIDs)
                    .execute()
                    .value
            } else {
                commentRows = try await client
                    .from("post_comments")
                    .select("post_id")
                    .in("post_id", values: postIds)
                    .execute()
                    .value
            }
            commentsByPostId = Dictionary(commentRows.map { ($0.post_id, 1) }, uniquingKeysWith: +)
        } catch {
            commentsByPostId = [:]
        }

        // Profiles for all poster user IDs
        let userIds = Array(Set(rows.map { $0.user_id }))
        let profilesByUserId: [String: SBProfileRow]
        do {
            let profiles: [SBProfileRow]
            let userUUIDs = userIds.compactMap(UUID.init(uuidString:))
            if userUUIDs.count == userIds.count, !userUUIDs.isEmpty {
                profiles = try await client
                    .from("profiles")
                    .select("id, username, avatar_path")
                    .in("id", values: userUUIDs)
                    .execute()
                    .value
            } else {
                profiles = try await client
                    .from("profiles")
                    .select("id, username, avatar_path")
                    .in("id", values: userIds)
                    .execute()
                    .value
            }
            profilesByUserId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        } catch {
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
                photoPaths: normalizedPhotoPaths(primary: row.photo_path, paths: row.photo_paths),
                make: row.make,
                model: row.model,
                carName: row.car_name,
                horsepower: row.horsepower,
                stage: row.stage,
                isJailbreak: row.is_jailbreak,
                vehicleClass: row.vehicle_class,
                likesCount: row.likes_count,
                commentsCount: commentsByPostId[row.id] ?? row.comments_count ?? 0,
                createdAt: date,
                username: profile?.username,
                avatarPath: profile?.avatar_path
            )
            post.isLiked = likedIds.contains(row.id)
            return post
        }
    }

    func countPosts(authorUserId: String? = nil) async throws -> Int {
        let baseQuery = client
            .from("community_posts")
            .select("id", head: true, count: .exact)
        let filteredQuery = if let authorUserId, !authorUserId.isEmpty {
            if let authorUUID = UUID(uuidString: authorUserId) {
                baseQuery.eq("user_id", value: authorUUID)
            } else {
                baseQuery.eq("user_id", value: authorUserId)
            }
        } else {
            baseQuery
        }

        let response = try await filteredQuery.execute()
        return response.count ?? 0
    }

    // MARK: - Share post

    func sharePost(car: Car, caption: String?, currentUserId: String, photoDataList: [Data]?) async throws -> CommunityPost {
        var photoPaths: [String] = []

        if let photoDataList {
            for data in photoDataList.prefix(5) {
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
                    photoPaths.append(path)
                } catch {
                }
            }
        }

        if photoPaths.isEmpty, let existingFileName = car.photoFileName {
            let existing = "\(currentUserId.lowercased())/\(car.id.uuidString).jpg"
            photoPaths = [existing]
            _ = existingFileName
        }

        let primaryPhotoPath = photoPaths.first

        let insert = SBInsertPost(
            user_id: currentUserId,
            car_id: car.id.uuidString,
            caption: caption?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : caption?.trimmingCharacters(in: .whitespacesAndNewlines),
            photo_path: primaryPhotoPath,
            photo_paths: photoPaths.isEmpty ? nil : photoPaths,
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
            photoPaths: normalizedPhotoPaths(primary: row.photo_path, paths: row.photo_paths),
            make: row.make,
            model: row.model,
            carName: row.car_name,
            horsepower: row.horsepower,
            stage: row.stage,
            isJailbreak: row.is_jailbreak,
            vehicleClass: row.vehicle_class,
            likesCount: 0,
            commentsCount: 0,
            createdAt: date
        )
    }

    // MARK: - Like / Unlike

    func likePost(postId: UUID, userId: String) async throws {
        if let userUUID = UUID(uuidString: userId) {
            let row = SBLikeInsert(post_id: postId, user_id: userUUID)
            _ = try await client
                .from("post_likes")
                .upsert(row, onConflict: "post_id, user_id")
                .execute()
        } else {
            let row = SBLikeRow(post_id: postId.uuidString, user_id: userId)
            _ = try await client
                .from("post_likes")
                .upsert(row, onConflict: "post_id, user_id")
                .execute()
        }
    }

    func unlikePost(postId: UUID, userId: String) async throws {
        if let userUUID = UUID(uuidString: userId) {
            _ = try await client
                .from("post_likes")
                .delete()
                .eq("post_id", value: postId)
                .eq("user_id", value: userUUID)
                .execute()
        } else {
            _ = try await client
                .from("post_likes")
                .delete()
                .eq("post_id", value: postId.uuidString)
                .eq("user_id", value: userId)
                .execute()
        }
    }

    // MARK: - Delete post

    func deletePost(post: CommunityPost) async throws {
        let pathsToRemove = Array(
            Set(
                ([post.photoPath].compactMap { $0 } + post.photoPaths)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )

        if !pathsToRemove.isEmpty {
            _ = try? await client.storage
                .from(photosBucket)
                .remove(paths: pathsToRemove)
        }

        _ = try await client
            .from("community_posts")
            .delete()
            .eq("id", value: post.id)
            .execute()
    }

    // MARK: - Comments

    /// Fetches all comments for a post, oldest first, enriched with profile data.
    func fetchComments(postId: UUID) async throws -> [PostComment] {
        let rows: [SBCommentRow] = try await client
            .from("post_comments")
            .select()
            .eq("post_id", value: postId)
            .order("created_at", ascending: true)
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        let userIds = Array(Set(rows.map { $0.user_id }))
        let profilesByUserId: [String: SBProfileRow]
        do {
            let profiles: [SBProfileRow]
            let userUUIDs = userIds.compactMap(UUID.init(uuidString:))
            if userUUIDs.count == userIds.count, !userUUIDs.isEmpty {
                profiles = try await client
                    .from("profiles")
                    .select("id, username, avatar_path")
                    .in("id", values: userUUIDs)
                    .execute()
                    .value
            } else {
                profiles = try await client
                    .from("profiles")
                    .select("id, username, avatar_path")
                    .in("id", values: userIds)
                    .execute()
                    .value
            }
            profilesByUserId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        } catch {
            profilesByUserId = [:]
        }

        return rows.compactMap { row -> PostComment? in
            guard let date = parseDate(row.created_at),
                  let id = UUID(uuidString: row.id),
                  let postId = UUID(uuidString: row.post_id) else { return nil }
            let profile = profilesByUserId[row.user_id]
            return PostComment(
                id: id,
                postId: postId,
                userId: row.user_id,
                body: row.body,
                createdAt: date,
                username: profile?.username,
                avatarPath: profile?.avatar_path
            )
        }
    }

    /// Posts a new comment and returns it enriched with the current user's profile.
    func postComment(postId: UUID, userId: String, body: String) async throws -> PostComment {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows: [SBCommentRow]
        if let userUUID = UUID(uuidString: userId) {
            let insert = SBInsertCommentUUID(
                post_id: postId,
                user_id: userUUID,
                body: trimmedBody
            )
            rows = try await client
                .from("post_comments")
                .insert(insert)
                .select()
                .execute()
                .value
        } else {
            let insert = SBInsertComment(
                post_id: postId.uuidString,
                user_id: userId,
                body: trimmedBody
            )
            rows = try await client
                .from("post_comments")
                .insert(insert)
                .select()
                .execute()
                .value
        }

        guard let row = rows.first,
              let date = parseDate(row.created_at),
              let id = UUID(uuidString: row.id),
              let pid = UUID(uuidString: row.post_id) else {
            throw NSError(domain: "CommunityService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Comment inserted but row read-back failed."])
        }

        // Fetch the poster's own profile for the returned comment
        let profileRows: [SBProfileRow]
        if let userUUID = UUID(uuidString: userId) {
            profileRows = (try? await client
                .from("profiles")
                .select("id, username, avatar_path")
                .eq("id", value: userUUID)
                .limit(1)
                .execute()
                .value) ?? []
        } else {
            profileRows = (try? await client
                .from("profiles")
                .select("id, username, avatar_path")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value) ?? []
        }
        let profile = profileRows.first

        return PostComment(
            id: id,
            postId: pid,
            userId: row.user_id,
            body: row.body,
            createdAt: date,
            username: profile?.username,
            avatarPath: profile?.avatar_path
        )
    }

    /// Deletes a comment by ID.
    func deleteComment(commentId: UUID) async throws {
        _ = try await client
            .from("post_comments")
            .delete()
            .eq("id", value: commentId.uuidString)
            .execute()
    }

    // MARK: - Public URL helpers

    func publicURL(for path: String) -> URL? {
        SupabaseClientProvider.publicObjectURL(bucket: photosBucket, path: path)
    }

    func avatarPublicURL(for path: String) -> URL? {
        SupabaseClientProvider.publicObjectURL(bucket: avatarsBucket, path: path)
    }

    // MARK: - Private helpers

    private func parseDate(_ value: String) -> Date? {
        isoFull.date(from: value) ?? isoBasic.date(from: value)
    }

    private func normalizedPhotoPaths(primary: String?, paths: [String]?) -> [String] {
        var result: [String] = []
        if let primary {
            let trimmed = primary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.append(trimmed)
            }
        }
        for path in paths ?? [] {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !result.contains(trimmed) {
                result.append(trimmed)
            }
        }
        return result
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
