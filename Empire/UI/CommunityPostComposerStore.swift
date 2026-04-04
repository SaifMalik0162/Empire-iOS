import Foundation
import SwiftUI
import Combine

enum CommunityPostTagLane: String, CaseIterable, Codable, Identifiable {
    case shops
    case parts
    case tunes
    case featuredMods

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shops: return "Shops"
        case .parts: return "Parts"
        case .tunes: return "Tunes"
        case .featuredMods: return "Featured Mods"
        }
    }

    var placeholder: String {
        switch self {
        case .shops: return "Add shop"
        case .parts: return "Add part"
        case .tunes: return "Add tune"
        case .featuredMods: return "Add featured mod"
        }
    }

    var icon: String {
        switch self {
        case .shops: return "building.2.crop.circle"
        case .parts: return "shippingbox"
        case .tunes: return "dial.medium"
        case .featuredMods: return "sparkles"
        }
    }

    var accentColor: Color {
        switch self {
        case .shops: return Color("EmpireMint")
        case .parts: return .cyan
        case .tunes: return Color(red: 0.98, green: 0.58, blue: 0.22)
        case .featuredMods: return Color(red: 0.94, green: 0.28, blue: 0.34)
        }
    }
}

struct CommunityPostTagSet: Codable, Equatable, Hashable {
    var shops: [String] = []
    var parts: [String] = []
    var tunes: [String] = []
    var featuredMods: [String] = []

    static let empty = CommunityPostTagSet()

    var isEmpty: Bool {
        shops.isEmpty && parts.isEmpty && tunes.isEmpty && featuredMods.isEmpty
    }

    var totalCount: Int {
        shops.count + parts.count + tunes.count + featuredMods.count
    }

    subscript(lane: CommunityPostTagLane) -> [String] {
        get {
            switch lane {
            case .shops: return shops
            case .parts: return parts
            case .tunes: return tunes
            case .featuredMods: return featuredMods
            }
        }
        set {
            switch lane {
            case .shops: shops = newValue
            case .parts: parts = newValue
            case .tunes: tunes = newValue
            case .featuredMods: featuredMods = newValue
            }
        }
    }
}

struct CommunityPostComposerDraft: Identifiable, Codable, Equatable {
    let id: UUID
    let originPostId: UUID?
    let createdAt: Date
    var selectedCarId: UUID?
    var caption: String
    var photoDataList: [Data]
    var selectedChallengeID: String?
    var selectedMeetID: UUID?
    var selectedMeetTitle: String?
    var tags: CommunityPostTagSet
    var scheduledFor: Date?
    var updatedAt: Date

    var isScheduled: Bool {
        scheduledFor != nil
    }

    var previewTitle: String {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.prefix(40))
        }
        if tags.totalCount > 0 {
            return "\(tags.totalCount) tag\(tags.totalCount == 1 ? "" : "s") ready"
        }
        return "Untitled draft"
    }

    var previewSubtitle: String {
        if let scheduledFor {
            return "Scheduled \(scheduledFor.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

@MainActor
final class CommunityPostComposerStore: ObservableObject {
    @Published private(set) var drafts: [CommunityPostComposerDraft] = []

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    var scheduledDrafts: [CommunityPostComposerDraft] {
        drafts.filter(\.isScheduled)
    }

    var unscheduledDrafts: [CommunityPostComposerDraft] {
        drafts.filter { !$0.isScheduled }
    }

    var dueScheduledDrafts: [CommunityPostComposerDraft] {
        let now = Date()
        return scheduledDrafts.filter { ($0.scheduledFor ?? .distantFuture) <= now }
    }

    func reload(userId: String? = nil) {
        let key = storageKey(for: userId)
        guard let data = defaults.data(forKey: key),
              let decoded = try? decoder.decode([CommunityPostComposerDraft].self, from: data) else {
            drafts = []
            return
        }
        drafts = sort(decoded)
    }

    func save(_ draft: CommunityPostComposerDraft, userId: String? = nil) {
        var next = drafts.filter { $0.id != draft.id }
        next.append(draft)
        persist(next, userId: userId)
    }

    func removeDraft(id: UUID, userId: String? = nil) {
        persist(drafts.filter { $0.id != id }, userId: userId)
    }

    func draft(id: UUID) -> CommunityPostComposerDraft? {
        drafts.first(where: { $0.id == id })
    }

    private func persist(_ drafts: [CommunityPostComposerDraft], userId: String? = nil) {
        let sortedDrafts = sort(drafts)
        let key = storageKey(for: userId)
        if let data = try? encoder.encode(sortedDrafts) {
            defaults.set(data, forKey: key)
        }
        self.drafts = sortedDrafts
    }

    private func sort(_ drafts: [CommunityPostComposerDraft]) -> [CommunityPostComposerDraft] {
        drafts.sorted { lhs, rhs in
            switch (lhs.scheduledFor, rhs.scheduledFor) {
            case let (left?, right?):
                if left != right {
                    return left < right
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func storageKey(for userId: String?) -> String {
        let resolved = (userId ?? UserDefaults.standard.string(forKey: "currentUserId") ?? "guest")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "community_post_composer_store_\(resolved.isEmpty ? "guest" : resolved)"
    }
}
