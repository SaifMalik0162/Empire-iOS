import Foundation
import Supabase
import UIKit

// MARK: - Domain models

struct CommunityPost: Identifiable, Equatable {
    let id: UUID
    let userId: String
    let carId: UUID?
    let caption: String?
    let challengeID: String?
    let linkedMeetId: UUID?
    let linkedMeetTitle: String?
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

enum CommunityInboxItemKind: String, CaseIterable {
    case like
    case comment
    case reply
}

struct CommunityInboxItem: Identifiable, Equatable {
    let id: String
    let kind: CommunityInboxItemKind
    let actorUserId: String
    let actorUsername: String?
    let actorAvatarPath: String?
    let postId: UUID
    let postCarName: String
    let postPhotoPath: String?
    let previewText: String?
    let createdAt: Date
}

struct CommunityPostProgramMetadata {
    let challengeID: String?
    let linkedMeetId: UUID?
    let linkedMeetTitle: String?

    var isEmpty: Bool {
        challengeID == nil && linkedMeetId == nil && linkedMeetTitle == nil
    }
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

private struct SBLikeActivityRow: Codable {
    let post_id: String
    let user_id: String
    let created_at: String?
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

private struct SBInboxPostRow: Codable {
    let id: String
    let user_id: String
    let car_name: String
    let photo_path: String?
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
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

    private enum ProgramMetadataCodec {
        static let prefix = "[[empire:"

        static func encode(caption: String?, metadata: CommunityPostProgramMetadata?) -> String? {
            let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let metadata, !metadata.isEmpty else {
                return trimmedCaption?.nilIfEmpty
            }

            var parts: [String] = []
            if let challengeID = metadata.challengeID?.nilIfEmpty {
                parts.append("challenge=\(challengeID)")
            }
            if let linkedMeetId = metadata.linkedMeetId {
                parts.append("meetId=\(linkedMeetId.uuidString.lowercased())")
            }
            if let linkedMeetTitle = metadata.linkedMeetTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
               let encoded = linkedMeetTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                parts.append("meetTitle=\(encoded)")
            }

            guard !parts.isEmpty else {
                return trimmedCaption?.nilIfEmpty
            }

            let metadataPrefix = "\(prefix)\(parts.joined(separator: ";"))]]"
            if let trimmedCaption = trimmedCaption?.nilIfEmpty {
                return "\(metadataPrefix) \(trimmedCaption)"
            }
            return metadataPrefix
        }

        static func decode(_ rawCaption: String?) -> (caption: String?, metadata: CommunityPostProgramMetadata) {
            guard let rawCaption, rawCaption.hasPrefix(prefix), let closeRange = rawCaption.range(of: "]]") else {
                return (
                    rawCaption?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    CommunityPostProgramMetadata(challengeID: nil, linkedMeetId: nil, linkedMeetTitle: nil)
                )
            }

            let metadataPayload = String(rawCaption[rawCaption.index(rawCaption.startIndex, offsetBy: prefix.count)..<closeRange.lowerBound])
            let strippedCaption = String(rawCaption[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

            var challengeID: String?
            var linkedMeetId: UUID?
            var linkedMeetTitle: String?

            for item in metadataPayload.split(separator: ";") {
                let pair = item.split(separator: "=", maxSplits: 1).map(String.init)
                guard pair.count == 2 else { continue }
                switch pair[0] {
                case "challenge":
                    challengeID = pair[1].nilIfEmpty
                case "meetId":
                    linkedMeetId = UUID(uuidString: pair[1])
                case "meetTitle":
                    linkedMeetTitle = pair[1].removingPercentEncoding?.nilIfEmpty ?? pair[1].nilIfEmpty
                default:
                    break
                }
            }

            return (
                strippedCaption,
                CommunityPostProgramMetadata(
                    challengeID: challengeID,
                    linkedMeetId: linkedMeetId,
                    linkedMeetTitle: linkedMeetTitle
                )
            )
        }
    }

    func authenticatedUserId() async throws -> String {
        do {
            let session = try await client.auth.session
            return session.user.id.uuidString.lowercased()
        } catch {
            let user = try await client.auth.user()
            return user.id.uuidString.lowercased()
        }
    }

    private func requireAuthenticatedUserId() async throws -> String {
        try await authenticatedUserId()
    }

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
            let decoded = ProgramMetadataCodec.decode(row.caption)
            var post = CommunityPost(
                id: UUID(uuidString: row.id) ?? UUID(),
                userId: row.user_id,
                carId: row.car_id.flatMap { UUID(uuidString: $0) },
                caption: decoded.caption,
                challengeID: decoded.metadata.challengeID,
                linkedMeetId: decoded.metadata.linkedMeetId,
                linkedMeetTitle: decoded.metadata.linkedMeetTitle,
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

    func sharePost(
        car: Car,
        caption: String?,
        currentUserId: String,
        photoDataList: [Data]?,
        metadata: CommunityPostProgramMetadata? = nil
    ) async throws -> CommunityPost {
        let authenticatedUserId = try await requireAuthenticatedUserId()
        var photoPaths: [String] = []

        if let photoDataList {
            for data in photoDataList.prefix(5) {
                let compressed = compressImageData(data, maxBytes: 900_000) ?? data
                let path = "\(authenticatedUserId)/community_\(UUID().uuidString).jpg"
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
            let existing = "\(authenticatedUserId)/\(car.id.uuidString).jpg"
            photoPaths = [existing]
            _ = existingFileName
        }

        let primaryPhotoPath = photoPaths.first
        let encodedCaption = ProgramMetadataCodec.encode(caption: caption, metadata: metadata)

        let insert = SBInsertPost(
            user_id: authenticatedUserId,
            car_id: car.id.uuidString,
            caption: encodedCaption,
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

        let decoded = ProgramMetadataCodec.decode(row.caption)
        return CommunityPost(
            id: UUID(uuidString: row.id) ?? UUID(),
            userId: row.user_id,
            carId: UUID(uuidString: row.car_id ?? ""),
            caption: decoded.caption,
            challengeID: decoded.metadata.challengeID,
            linkedMeetId: decoded.metadata.linkedMeetId,
            linkedMeetTitle: decoded.metadata.linkedMeetTitle,
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
        let authenticatedUserId = try await requireAuthenticatedUserId()
        if let userUUID = UUID(uuidString: authenticatedUserId) {
            let row = SBLikeInsert(post_id: postId, user_id: userUUID)
            _ = try await client
                .from("post_likes")
                .upsert(row, onConflict: "post_id, user_id")
                .execute()
        } else {
            let row = SBLikeRow(post_id: postId.uuidString, user_id: authenticatedUserId)
            _ = try await client
                .from("post_likes")
                .upsert(row, onConflict: "post_id, user_id")
                .execute()
        }
    }

    func unlikePost(postId: UUID, userId: String) async throws {
        let authenticatedUserId = try await requireAuthenticatedUserId()
        if let userUUID = UUID(uuidString: authenticatedUserId) {
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
                .eq("user_id", value: authenticatedUserId)
                .execute()
        }
    }

    // MARK: - Delete post

    func deletePost(post: CommunityPost) async throws {
        let authenticatedUserId = try await requireAuthenticatedUserId()
        guard post.userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == authenticatedUserId else {
            throw NSError(domain: "CommunityService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only delete your own posts."])
        }

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
    func postComment(postId: UUID, preferredUserId: String, body: String) async throws -> PostComment {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let userId = try await requireAuthenticatedUserId()
        let insert = SBInsertComment(
            post_id: postId.uuidString.lowercased(),
            user_id: userId,
            body: trimmedBody
        )
        let rows: [SBCommentRow] = try await client
            .from("post_comments")
            .insert(insert)
            .select()
            .execute()
            .value

        guard let row = rows.first,
              let date = parseDate(row.created_at),
              let id = UUID(uuidString: row.id),
              let pid = UUID(uuidString: row.post_id) else {
            throw NSError(domain: "CommunityService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Comment inserted but row read-back failed."])
        }

        // Fetch the poster's own profile for the returned comment
        let profileRows: [SBProfileRow] = (try? await client
            .from("profiles")
            .select("id, username, avatar_path")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value) ?? []
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
        _ = try await requireAuthenticatedUserId()
        _ = try await client
            .from("post_comments")
            .delete()
            .eq("id", value: commentId.uuidString)
            .execute()
    }

    // MARK: - Inbox activity

    func fetchInboxItems(currentUserId: String, limit: Int = 32) async throws -> [CommunityInboxItem] {
        let postRows: [SBInboxPostRow] = try await {
            if let userUUID = UUID(uuidString: currentUserId) {
                return try await client
                    .from("community_posts")
                    .select("id, user_id, car_name, photo_path")
                    .eq("user_id", value: userUUID)
                    .order("created_at", ascending: false)
                    .limit(limit)
                    .execute()
                    .value
            } else {
                return try await client
                    .from("community_posts")
                    .select("id, user_id, car_name, photo_path")
                    .eq("user_id", value: currentUserId)
                    .order("created_at", ascending: false)
                    .limit(limit)
                    .execute()
                    .value
            }
        }()

        let ownedPostsById = Dictionary(uniqueKeysWithValues: postRows.map { ($0.id, $0) })
        let ownedPostIds = Array(ownedPostsById.keys)
        let ownedPostUUIDs = ownedPostIds.compactMap(UUID.init(uuidString:))

        let ownPostComments: [SBCommentRow]
        if ownedPostUUIDs.count == ownedPostIds.count, !ownedPostUUIDs.isEmpty {
            ownPostComments = (try? await client
                .from("post_comments")
                .select("id, post_id, user_id, body, created_at")
                .in("post_id", values: ownedPostUUIDs)
                .order("created_at", ascending: false)
                .limit(limit * 2)
                .execute()
                .value) ?? []
        } else if !ownedPostIds.isEmpty {
            ownPostComments = (try? await client
                .from("post_comments")
                .select("id, post_id, user_id, body, created_at")
                .in("post_id", values: ownedPostIds)
                .order("created_at", ascending: false)
                .limit(limit * 2)
                .execute()
                .value) ?? []
        } else {
            ownPostComments = []
        }

        let ownPostLikes: [SBLikeActivityRow]
        if ownedPostUUIDs.count == ownedPostIds.count, !ownedPostUUIDs.isEmpty {
            ownPostLikes = (try? await client
                .from("post_likes")
                .select("post_id, user_id, created_at")
                .in("post_id", values: ownedPostUUIDs)
                .order("created_at", ascending: false)
                .limit(limit * 2)
                .execute()
                .value) ?? []
        } else if !ownedPostIds.isEmpty {
            ownPostLikes = (try? await client
                .from("post_likes")
                .select("post_id, user_id, created_at")
                .in("post_id", values: ownedPostIds)
                .order("created_at", ascending: false)
                .limit(limit * 2)
                .execute()
                .value) ?? []
        } else {
            ownPostLikes = []
        }

        let myCommentRows: [SBCommentRow]
        if let userUUID = UUID(uuidString: currentUserId) {
            myCommentRows = (try? await client
                .from("post_comments")
                .select("id, post_id, user_id, body, created_at")
                .eq("user_id", value: userUUID)
                .order("created_at", ascending: false)
                .limit(limit * 3)
                .execute()
                .value) ?? []
        } else {
            myCommentRows = (try? await client
                .from("post_comments")
                .select("id, post_id, user_id, body, created_at")
                .eq("user_id", value: currentUserId)
                .order("created_at", ascending: false)
                .limit(limit * 3)
                .execute()
                .value) ?? []
        }

        let replyPostIds = Array(
            Set(
                myCommentRows
                    .map(\.post_id)
                    .filter { ownedPostsById[$0] == nil }
            )
        )
        let replyPostUUIDs = replyPostIds.compactMap(UUID.init(uuidString:))

        let replyRows: [SBCommentRow]
        if replyPostUUIDs.count == replyPostIds.count, !replyPostUUIDs.isEmpty {
            replyRows = (try? await client
                .from("post_comments")
                .select("id, post_id, user_id, body, created_at")
                .in("post_id", values: replyPostUUIDs)
                .order("created_at", ascending: false)
                .limit(limit * 3)
                .execute()
                .value) ?? []
        } else if !replyPostIds.isEmpty {
            replyRows = (try? await client
                .from("post_comments")
                .select("id, post_id, user_id, body, created_at")
                .in("post_id", values: replyPostIds)
                .order("created_at", ascending: false)
                .limit(limit * 3)
                .execute()
                .value) ?? []
        } else {
            replyRows = []
        }

        let replyPostRows: [SBInboxPostRow]
        if replyPostUUIDs.count == replyPostIds.count, !replyPostUUIDs.isEmpty {
            replyPostRows = (try? await client
                .from("community_posts")
                .select("id, user_id, car_name, photo_path")
                .in("id", values: replyPostUUIDs)
                .execute()
                .value) ?? []
        } else if !replyPostIds.isEmpty {
            replyPostRows = (try? await client
                .from("community_posts")
                .select("id, user_id, car_name, photo_path")
                .in("id", values: replyPostIds)
                .execute()
                .value) ?? []
        } else {
            replyPostRows = []
        }

        let replyPostsById = Dictionary(uniqueKeysWithValues: replyPostRows.map { ($0.id, $0) })

        let actorUserIds = Set(
            ownPostComments.map(\.user_id)
            + ownPostLikes.map(\.user_id)
            + replyRows.map(\.user_id)
        ).subtracting([currentUserId])

        let actorProfilesByUserId: [String: SBProfileRow]
        do {
            let actorIds = Array(actorUserIds)
            let actorUUIDs = actorIds.compactMap(UUID.init(uuidString:))
            let profiles: [SBProfileRow]
            if actorUUIDs.count == actorIds.count, !actorUUIDs.isEmpty {
                profiles = try await client
                    .from("profiles")
                    .select("id, username, avatar_path")
                    .in("id", values: actorUUIDs)
                    .execute()
                    .value
            } else if !actorIds.isEmpty {
                profiles = try await client
                    .from("profiles")
                    .select("id, username, avatar_path")
                    .in("id", values: actorIds)
                    .execute()
                    .value
            } else {
                profiles = []
            }
            actorProfilesByUserId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        } catch {
            actorProfilesByUserId = [:]
        }

        let latestOwnCommentByPostId = Dictionary(
            myCommentRows.map { ($0.post_id, parseDate($0.created_at) ?? .distantPast) },
            uniquingKeysWith: max
        )

        var items: [CommunityInboxItem] = []

        for like in ownPostLikes where like.user_id != currentUserId {
            guard let createdAtString = like.created_at,
                  let createdAt = parseDate(createdAtString),
                  let post = ownedPostsById[like.post_id],
                  let postId = UUID(uuidString: like.post_id) else { continue }
            let profile = actorProfilesByUserId[like.user_id]
            items.append(
                CommunityInboxItem(
                    id: "like-\(like.post_id)-\(like.user_id)-\(createdAtString)",
                    kind: .like,
                    actorUserId: like.user_id,
                    actorUsername: profile?.username,
                    actorAvatarPath: profile?.avatar_path,
                    postId: postId,
                    postCarName: post.car_name,
                    postPhotoPath: post.photo_path,
                    previewText: nil,
                    createdAt: createdAt
                )
            )
        }

        for comment in ownPostComments where comment.user_id != currentUserId {
            guard let createdAt = parseDate(comment.created_at),
                  let post = ownedPostsById[comment.post_id],
                  let postId = UUID(uuidString: comment.post_id) else { continue }
            let profile = actorProfilesByUserId[comment.user_id]
            items.append(
                CommunityInboxItem(
                    id: "comment-\(comment.id)",
                    kind: .comment,
                    actorUserId: comment.user_id,
                    actorUsername: profile?.username,
                    actorAvatarPath: profile?.avatar_path,
                    postId: postId,
                    postCarName: post.car_name,
                    postPhotoPath: post.photo_path,
                    previewText: comment.body,
                    createdAt: createdAt
                )
            )
        }

        for reply in replyRows where reply.user_id != currentUserId {
            guard let createdAt = parseDate(reply.created_at),
                  let latestMyComment = latestOwnCommentByPostId[reply.post_id],
                  createdAt > latestMyComment,
                  let post = replyPostsById[reply.post_id],
                  let postId = UUID(uuidString: reply.post_id) else { continue }
            let profile = actorProfilesByUserId[reply.user_id]
            items.append(
                CommunityInboxItem(
                    id: "reply-\(reply.id)",
                    kind: .reply,
                    actorUserId: reply.user_id,
                    actorUsername: profile?.username,
                    actorAvatarPath: profile?.avatar_path,
                    postId: postId,
                    postCarName: post.car_name,
                    postPhotoPath: post.photo_path,
                    previewText: reply.body,
                    createdAt: createdAt
                )
            )
        }

        return Array(
            items
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(limit)
        )
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
