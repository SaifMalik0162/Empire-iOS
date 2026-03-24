import Foundation
import SwiftUI
import Combine
import OSLog

@MainActor
final class CommunityViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String? = nil
    @Published var hasMore = true
    @Published var totalPostsCount = 0

    private let service = SupabaseCommunityService()
    private let logger = Logger(subsystem: "com.empire.app", category: "community-vm")
    private let pageSize = 40
    private var currentOffset = 0
    private let authorUserId: String?
    private var currentUserId: String { UserDefaults.standard.string(forKey: "currentUserId") ?? "" }

    init(userId: String? = nil) {
        self.authorUserId = userId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? userId?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
    }

    // MARK: - Fetch

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        currentOffset = 0
        hasMore = true

        do {
            async let fetchedTask = service.fetchFeed(
                currentUserId: currentUserId,
                limit: pageSize,
                offset: 0,
                authorUserId: authorUserId
            )
            async let totalTask = service.countPosts(authorUserId: authorUserId)

            let fetched = try await fetchedTask
            let total = try await totalTask
            posts = fetched
            totalPostsCount = total
            currentOffset = fetched.count
            hasMore = fetched.count == pageSize
        } catch {
            let msg = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = msg.isEmpty ? "Failed to load feed." : msg
            logger.error("refresh failed: \(String(describing: error), privacy: .public)")
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            let fetched = try await service.fetchFeed(
                currentUserId: currentUserId,
                limit: pageSize,
                offset: currentOffset,
                authorUserId: authorUserId
            )
            posts.append(contentsOf: fetched)
            currentOffset += fetched.count
            hasMore = fetched.count == pageSize
        } catch {
            logger.error("loadMore failed: \(String(describing: error), privacy: .public)")
        }
        isLoadingMore = false
    }

    // MARK: - Share

    func sharePost(car: Car, caption: String?, photoData: Data?) async throws -> CommunityPost {
        let userId = currentUserId
        guard !userId.isEmpty else {
            throw NSError(domain: "Community", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        let post = try await service.sharePost(car: car, caption: caption, currentUserId: userId, photoData: photoData)
        posts.insert(post, at: 0)
        if authorUserId == nil || authorUserId == userId {
            totalPostsCount += 1
        }
        NotificationCenter.default.post(name: .empireCommunityDidPost, object: nil)
        return post
    }

    // MARK: - Like / Unlike

    func toggleLike(postId: UUID) async {
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        let wasLiked = posts[idx].isLiked
        // Optimistic update
        posts[idx].isLiked = !wasLiked
        posts[idx].likesCount += wasLiked ? -1 : 1

        let userId = currentUserId
        do {
            if wasLiked {
                try await service.unlikePost(postId: postId, userId: userId)
            } else {
                try await service.likePost(postId: postId, userId: userId)
            }
        } catch {
            // Revert on failure
            posts[idx].isLiked = wasLiked
            posts[idx].likesCount += wasLiked ? 1 : -1
            logger.error("toggleLike failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Delete post

    func deletePost(postId: UUID) async {
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts.remove(at: idx)
        totalPostsCount = max(0, totalPostsCount - 1)
        do {
            try await service.deletePost(postId: postId)
        } catch {
            logger.error("deletePost failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Comment count helpers (called by CommentSheetView)

    /// Optimistically bumps the comment count for a post after a successful insert.
    func incrementCommentCount(postId: UUID) {
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[idx].commentsCount += 1
    }

    /// Optimistically decrements the comment count for a post after a successful delete.
    func decrementCommentCount(postId: UUID) {
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[idx].commentsCount = max(0, posts[idx].commentsCount - 1)
    }

    // MARK: - Public URL helpers

    func photoURL(for post: CommunityPost) -> URL? {
        guard let path = post.photoPath else { return nil }
        return service.publicURL(for: path)
    }

    func avatarURL(for post: CommunityPost) -> URL? {
        guard let path = post.avatarPath, !path.isEmpty else { return nil }
        let base = SupabaseConfig.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/storage/v1/object/public/avatars/\(path)")
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let empireCommunityDidPost = Notification.Name("EmpireCommunityDidPost")
}
