import Foundation
import Combine
import UserNotifications
import Supabase
import OSLog

// MARK: - MeetsViewModel

@MainActor
final class MeetsViewModel: ObservableObject {
    @Published var rsvp: [UUID: Bool] = [:]
    @Published var checkedIn: [UUID: Bool] = [:]
    @Published var notifyOn: [UUID: Bool] = [:]
    @Published var calendarSaved: [UUID: Bool] = [:]

    private let _service: (any MeetsParticipationService)?

    nonisolated init(service: (any MeetsParticipationService)? = nil) {
        self._service = service
    }

    private var service: any MeetsParticipationService {
        _service ?? SupabaseMeetsParticipationService()
    }

    private let logger = Logger(subsystem: "com.empire.app", category: "meets-participation")

    private static let notifyDefaultsKey   = "empire.meets.notifyOn"
    private static let calendarDefaultsKey = "empire.meets.calendarSaved"

    // MARK: - Load

    func load(meets: [Meet]) async {
        guard !meets.isEmpty else { return }

        // Restore persisted prefs before network call
        restoreNotifyState(for: meets)
        restoreCalendarSaved(for: meets)

        do {
            let statuses = try await service.fetchStatuses(for: meets.map { $0.id })
            self.rsvp      = statuses.reduce(into: [:]) { $0[$1.meetId] = $1.isRSVPed }
            self.checkedIn = statuses.reduce(into: [:]) { $0[$1.meetId] = $1.isCheckedIn }
        } catch {
            logger.error("Failed to load participation statuses: \(error, privacy: .public)")
        }
    }

    // MARK: - Calendar saved state

    func markCalendarSaved(for meet: Meet) {
        calendarSaved[meet.id] = true
        persistCalendarSaved()
    }

    private func restoreCalendarSaved(for meets: [Meet]) {
        let saved = UserDefaults.standard.dictionary(forKey: Self.calendarDefaultsKey) as? [String: Bool] ?? [:]
        calendarSaved = meets.reduce(into: [:]) { dict, meet in
            dict[meet.id] = saved[meet.id.uuidString] ?? false
        }
    }

    private func persistCalendarSaved() {
        let dict = calendarSaved.reduce(into: [String: Bool]()) { $0[$1.key.uuidString] = $1.value }
        UserDefaults.standard.set(dict, forKey: Self.calendarDefaultsKey)
    }

    // MARK: - Notify persistence helpers

    private func restoreNotifyState(for meets: [Meet]) {
        let saved = UserDefaults.standard.dictionary(forKey: Self.notifyDefaultsKey) as? [String: Bool] ?? [:]
        notifyOn = meets.reduce(into: [:]) { dict, meet in
            dict[meet.id] = saved[meet.id.uuidString] ?? false
        }
    }

    private func persistNotifyState() {
        let dict = notifyOn.reduce(into: [String: Bool]()) { $0[$1.key.uuidString] = $1.value }
        UserDefaults.standard.set(dict, forKey: Self.notifyDefaultsKey)
    }

    // MARK: - RSVP

    func toggleRSVP(for meet: Meet) async {
        let current = rsvp[meet.id] ?? false
        // Optimistic update
        rsvp[meet.id] = !current
        do {
            if current {
                try await service.unrsvp(meetId: meet.id)
            } else {
                try await service.rsvp(meetId: meet.id)
            }
        } catch {
            // Rollback on failure
            rsvp[meet.id] = current
            logger.error("RSVP toggle failed for meet \(meet.id.uuidString, privacy: .public): \(error, privacy: .public)")
        }
    }

    // MARK: - Check-In

    func checkIn(for meet: Meet) async {
        guard !(checkedIn[meet.id] ?? false) else { return }
        do {
            try await service.checkIn(meetId: meet.id)
            checkedIn[meet.id] = true
        } catch {
            logger.error("Check-in failed for meet \(meet.id.uuidString, privacy: .public): \(error, privacy: .public)")
        }
    }

    // MARK: - Notifications

    func toggleNotification(for meet: Meet) async {
        let center = UNUserNotificationCenter.current()
        let isOn = notifyOn[meet.id] ?? false

        if isOn {
            center.removePendingNotificationRequests(withIdentifiers: [notificationId(for: meet)])
            notifyOn[meet.id] = false
            persistNotifyState()
            return
        }

        // Request permission if needed
        let settings = await center.notificationSettings()
        if settings.authorizationStatus != .authorized {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else { return }
            } catch {
                return
            }
        }

        guard meet.date.timeIntervalSinceNow > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Meet"
        content.body = "\(meet.title) in \(meet.city) starts in 1 hour."
        content.sound = .default

        // Fire 1 hour before, minimum 5 seconds from now
        let fireDate = meet.date.addingTimeInterval(-3600)
        let interval = max(fireDate.timeIntervalSinceNow, 5)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(
            identifier: notificationId(for: meet),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            notifyOn[meet.id] = true
            persistNotifyState()
        } catch {
            logger.error("Notification scheduling failed for meet \(meet.id.uuidString, privacy: .public): \(error, privacy: .public)")
        }
    }

    private func notificationId(for meet: Meet) -> String {
        "empire_meet_notify_\(meet.id.uuidString)"
    }
}

// MARK: - Participation Status DTO

struct MeetParticipationStatus: Sendable {
    let meetId: UUID
    let isRSVPed: Bool
    let isCheckedIn: Bool
}

// MARK: - Protocol

protocol MeetsParticipationService: Sendable {
    func fetchStatuses(for meetIds: [UUID]) async throws -> [MeetParticipationStatus]
    func rsvp(meetId: UUID) async throws
    func unrsvp(meetId: UUID) async throws
    func checkIn(meetId: UUID) async throws
}

// MARK: - Supabase Implementation

struct SupabaseMeetsParticipationService: MeetsParticipationService {

    private var client: SupabaseClient { SupabaseClientProvider.client }
    private let logger = Logger(subsystem: "com.empire.app", category: "supabase-participation")

    // MARK: - Codable row types

    private struct RsvpRow: Codable {
        let meet_id: String
    }

    private struct CheckinRow: Codable {
        let meet_id: String
    }

    // RLS on meets_rsvp / meets_checkins requires user_id = auth.uid().
    // The Supabase client sends the JWT automatically, but the row must
    // explicitly carry user_id so the policy can match it on INSERT.
    private struct RsvpInsert: Encodable {
        let meet_id: String
        let user_id: String
    }

    private struct CheckinInsert: Encodable {
        let meet_id: String
        let user_id: String
    }

    // MARK: - Resolve current user id

    /// Returns the authenticated user's UUID string, throwing if no session exists.
    private func currentUserId() async throws -> String {
        let user = try await client.auth.user()
        return user.id.uuidString
    }

    // MARK: - fetchStatuses

    func fetchStatuses(for meetIds: [UUID]) async throws -> [MeetParticipationStatus] {
        guard !meetIds.isEmpty else { return [] }
        let ids = meetIds.map { $0.uuidString }
        let userId = try await currentUserId()

        async let rsvpFetch: [RsvpRow] = client
            .from("meets_rsvp")
            .select("meet_id")
            .eq("user_id", value: userId)
            .in("meet_id", values: ids)
            .execute()
            .value

        async let checkinFetch: [CheckinRow] = client
            .from("meets_checkins")
            .select("meet_id")
            .eq("user_id", value: userId)
            .in("meet_id", values: ids)
            .execute()
            .value

        let (rsvpRows, checkinRows) = try await (rsvpFetch, checkinFetch)

        let rsvpSet    = Set(rsvpRows.map    { $0.meet_id.uppercased() })
        let checkinSet = Set(checkinRows.map { $0.meet_id.uppercased() })

        return meetIds.map { id in
            let key = id.uuidString.uppercased()
            return MeetParticipationStatus(
                meetId: id,
                isRSVPed: rsvpSet.contains(key),
                isCheckedIn: checkinSet.contains(key)
            )
        }
    }

    // MARK: - RSVP

    func rsvp(meetId: UUID) async throws {
        let userId = try await currentUserId()
        let body = RsvpInsert(meet_id: meetId.uuidString, user_id: userId)
        try await client
            .from("meets_rsvp")
            .insert(body, returning: .minimal)
            .execute()
    }

    func unrsvp(meetId: UUID) async throws {
        let userId = try await currentUserId()
        try await client
            .from("meets_rsvp")
            .delete()
            .eq("meet_id", value: meetId.uuidString)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Check-In

    func checkIn(meetId: UUID) async throws {
        let userId = try await currentUserId()
        let body = CheckinInsert(meet_id: meetId.uuidString, user_id: userId)
        try await client
            .from("meets_checkins")
            .upsert(body, returning: .minimal)
            .execute()
    }
}
