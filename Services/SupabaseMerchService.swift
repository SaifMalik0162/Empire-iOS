import Foundation
import Supabase

struct SBMerchRow: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let price_string: String
    let image_name: String
    let category: String
    let updated_at: String?
}

final class SupabaseMerchService {
    private var supabaseClient: SupabaseClient { SupabaseClientProvider.shared }

    func fetchMerch() async throws -> [MerchItem] {
        let rows: [SBMerchRow] = try await AppTelemetry.shared.measure(operation: "merch.fetch") {
            try await supabaseClient
                .from("merch_items")
                .select()
                .order("updated_at", ascending: false)
                .execute()
                .value
        }
        AppTelemetry.shared.track(event: "merch.fetch.success", metadata: ["count": String(rows.count)])
        return Self.mapRowsToMerchItems(rows)
    }

    static func mapRowsToMerchItems(_ rows: [SBMerchRow]) -> [MerchItem] {
        rows.map { r in
            let normalizedCategory = r.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cat: MerchCategory
            switch normalizedCategory {
            case "accessories":
                cat = .accessories
            case "banners":
                cat = .banners
            default:
                cat = .apparel
            }

            return MerchItem(
                stableIDSeed: r.id,
                name: r.name.trimmingCharacters(in: .whitespacesAndNewlines),
                price: r.price_string.trimmingCharacters(in: .whitespacesAndNewlines),
                imageName: r.image_name.trimmingCharacters(in: .whitespacesAndNewlines),
                category: cat
            )
        }
    }
}
