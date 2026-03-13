import Foundation
import Supabase
import OSLog

struct SBMeetRow: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let city: String
    let date: String
    let latitude: Double?
    let longitude: Double?
}

final class SupabaseMeetsService {
    private let supabaseClient: SupabaseClient = SupabaseClientProvider.client
    private let logger = AppLogger.supabaseMeets
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoFallbackFormatter = ISO8601DateFormatter()
    private let sqlFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ssXXXXX"
        return f
    }()

    func fetchUpcomingMeets() async throws -> [Meet] {
        let nowISO = isoFallbackFormatter.string(from: Date())
        let rows: [SBMeetRow] = try await supabaseClient
            .from("meets")
            .select()
            .gt("date", value: nowISO)
            .order("date", ascending: true)
            .execute()
            .value

        var droppedRows = 0
        let mapped = rows.compactMap { row -> Meet? in
            guard let d = parseDate(row.date) else {
                droppedRows += 1
                return nil
            }
            return Meet(title: row.title, city: row.city, date: d)
        }
        if droppedRows > 0 {
            logger.warning("Dropped \(droppedRows) meet rows due to unparseable date values")
        }
        return mapped
    }

    private func parseDate(_ value: String) -> Date? {
        if let d = isoFormatter.date(from: value) { return d }
        if let d = isoFallbackFormatter.date(from: value) { return d }
        if let d = sqlFormatter.date(from: value) { return d }
        return nil
    }
}
