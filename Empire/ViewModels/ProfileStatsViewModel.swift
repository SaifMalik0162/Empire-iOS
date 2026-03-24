import Foundation
import Combine
import OSLog
import Supabase

protocol ProfileStatsServiceProviding {
    func countMeetRSVPs(for userId: String) async throws -> Int
    func countMerchOrders(for userId: String) async throws -> Int
}

struct SupabaseProfileStatsService: ProfileStatsServiceProviding {
    private let client = SupabaseClientProvider.client
    private let merchOrdersTable = "merch_orders"

    func countMeetRSVPs(for userId: String) async throws -> Int {
        let response = try await client
            .from("meets_rsvp")
            .select("meet_id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .execute()
        return response.count ?? 0
    }

    func countMerchOrders(for userId: String) async throws -> Int {
        let response = try await client
            .from(merchOrdersTable)
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .execute()
        return response.count ?? 0
    }
}

@MainActor
final class ProfileStatsViewModel: ObservableObject {
    @Published private(set) var meetsCount: Int = 0
    @Published private(set) var merchCount: Int = 0

    private let service: ProfileStatsServiceProviding
    private let logger = Logger(subsystem: "com.empire.app", category: "profile-stats")

    init() {
        self.service = SupabaseProfileStatsService()
    }

    init(service: ProfileStatsServiceProviding) {
        self.service = service
    }

    func load(for userId: String) async {
        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserId.isEmpty else {
            meetsCount = 0
            merchCount = 0
            return
        }

        do {
            meetsCount = try await service.countMeetRSVPs(for: trimmedUserId)
        } catch {
            logger.error("Failed to load meet stats for user \(trimmedUserId, privacy: .public): \(String(describing: error), privacy: .public)")
            meetsCount = 0
        }

        do {
            merchCount = try await service.countMerchOrders(for: trimmedUserId)
        } catch {
            logger.error("Failed to load merch stats for user \(trimmedUserId, privacy: .public): \(String(describing: error), privacy: .public)")
            merchCount = 0
        }
    }

    func reset() {
        meetsCount = 0
        merchCount = 0
    }
}
