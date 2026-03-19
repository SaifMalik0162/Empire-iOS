import Foundation
import Supabase
import OSLog

// MARK: - Supabase row type (internal to this file)
private struct SBMeetRow: Codable, Equatable, Identifiable {
    let id: UUID          // uuid column — Supabase Swift client decodes uuid → UUID natively
    let title: String
    let city: String
    let date: String
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Service

final class SupabaseMeetsService {
    private let supabaseClient: SupabaseClient = SupabaseClientProvider.client
    private let logger = AppLogger.supabaseMeets

    // Full ISO 8601 with fractional seconds (Supabase default)
    private let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // ISO 8601 without fractional seconds
    private let isoBasic = ISO8601DateFormatter()

    // Plain SQL timestamp format e.g. "2025-08-10 20:00:00+00"
    private let sqlFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ssXXXXX"
        return f
    }()

    // MARK: - Public API

    func fetchUpcomingMeets() async throws -> [Meet] {
        let nowISO = isoBasic.string(from: Date())

        let rows: [SBMeetRow] = try await supabaseClient
            .from("meets")
            .select()
            .gt("date", value: nowISO)
            .order("date", ascending: true)
            .execute()
            .value

        var droppedRows = 0
        let meets = rows.compactMap { row -> Meet? in
            guard let date = parseDate(row.date) else {
                droppedRows += 1
                logger.warning("Could not parse date '\(row.date, privacy: .public)' for meet id \(row.id, privacy: .public)")
                return nil
            }
            return Meet(
                id: row.id,
                title: row.title,
                city: row.city,
                date: date,
                latitude: row.latitude,
                longitude: row.longitude
            )
        }

        if droppedRows > 0 {
            logger.warning("Dropped \(droppedRows) meet rows due to unparseable date values")
        }
        return meets
    }

    // MARK: - Date parsing (tries three formats)

    private func parseDate(_ value: String) -> Date? {
        if let d = isoFull.date(from: value) { return d }
        if let d = isoBasic.date(from: value) { return d }
        if let d = sqlFormatter.date(from: value) { return d }
        return nil
    }
}
