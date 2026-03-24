import SwiftUI
import MapKit
import EventKit

// MARK: - MeetsView

struct MeetsView: View {
    @StateObject private var meetsVM = MeetsViewModel()
    @State private var meets: [Meet] = []
    @State private var isLoadingMeets = false
    @State private var meetsError: String?
    @State private var scrollOffset: CGFloat = 0
    @State private var showMap = false
    @State private var showQR = false
    @State private var qrTargetMeet: Meet?
    @State private var showCheckInSuccess = false
    @State private var checkedInMeetTitle = ""
    @State private var showQRAlert = false
    @State private var qrAlertMessage = ""

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.95)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color("EmpireMint").opacity(0.18), .clear],
                center: .top, startRadius: 20, endRadius: 300
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                // Scroll offset tracker
                GeometryReader { geo in
                    Color.clear
                        .preference(key: OffsetKey.self, value: geo.frame(in: .named("scroll")).minY)
                }
                .frame(height: 0)

                VStack(spacing: 22) {
                    MeetsHeader(
                        meets: meets,
                        showMap: $showMap
                    )
                    .padding(.top, 12)
                    .padding(.horizontal, 18)

                    if isLoadingMeets {
                        ProgressView("Loading meets...")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if let err = meetsError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if meets.isEmpty {
                        emptyMeetsView
                    } else {
                        ForEach(meets) { meet in
                            MeetCard(
                                meet: meet,
                                meetsVM: meetsVM,
                                onQRScan: {
                                    qrTargetMeet = meet
                                    showQR = true
                                },
                                onAddToCalendar: { addToCalendar(meet: meet) }
                            )
                            .padding(.horizontal, 18)
                            .shadow(color: Color("EmpireMint").opacity(0.22), radius: 20, x: 0, y: 12)
                            .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 6)
                            .modifier(ParallaxEffect(y: scrollOffset, strength: 16))
                        }
                    }

                    Color.clear.frame(height: 100)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(OffsetKey.self) { scrollOffset = $0 }
        }
        .task { await loadMeets() }
        .sheet(isPresented: $showMap) {
            MeetsMapSheet(meets: meets)
        }
        .fullScreenCover(isPresented: $showQR) {
            QRScanFlow(
                meet: qrTargetMeet,
                onCode: { code in
                    showQR = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        handleQRCode(code, for: qrTargetMeet)
                    }
                },
                onCancel: { showQR = false }
            )
        }
        .fullScreenCover(isPresented: $showCheckInSuccess) {
            CheckInSuccessView(meetTitle: checkedInMeetTitle) {
                showCheckInSuccess = false
            }
        }
        .alert("QR Code", isPresented: $showQRAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(qrAlertMessage)
        }
    }

    // MARK: - Helpers

    private var emptyMeetsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 56))
                .foregroundColor(Color("EmpireMint").opacity(0.5))
            Text("No upcoming meets")
                .font(.headline)
                .foregroundColor(.white)
            Text("Check back soon for new events")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func loadMeets() async {
        isLoadingMeets = true
        meetsError = nil
        let service = SupabaseMeetsService()
        do {
            let items = try await service.fetchUpcomingMeets()
            meets = items
            await meetsVM.load(meets: items)
        } catch {
            let msg = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            meetsError = msg.isEmpty ? "Failed to load meets" : msg
        }
        isLoadingMeets = false
    }

    private func handleQRCode(_ code: String, for meet: Meet?) {
        guard let meet else { return }
        let isValid = code.contains(meet.id.uuidString) || code == meet.id.uuidString
        if isValid {
            Task {
                await meetsVM.checkIn(for: meet)
                checkedInMeetTitle = meet.title
                showCheckInSuccess = true
            }
        } else {
            qrAlertMessage = "❌ Invalid QR code for this meet."
            showQRAlert = true
        }
    }

    // MARK: - Calendar
    // EKEventStore communicates over XPC. The store must stay alive until the
    // permission callback fires — capture it strongly inside the closure so ARC
    // doesn't release it before the XPC reply arrives.
    // Note: EKErrorDomain Code=40 / calaccessd errors are Simulator-only bugs;
    // calendar saving works correctly on a real device.

    @MainActor
    private func addToCalendar(meet: Meet) {
        let store = EKEventStore()
        let save = { [store] (granted: Bool) in
            guard granted else { return }

            guard let calendar = store.defaultCalendarForNewEvents else { return }

            let event        = EKEvent(eventStore: store)
            event.title      = meet.title
            event.location   = meet.city
            event.startDate  = meet.date
            event.endDate    = meet.date.addingTimeInterval(3600 * 3)
            event.notes      = "Empire Connect Meet – \(meet.city)"
            event.calendar   = calendar
            event.alarms     = nil

            do {
                try store.save(event, span: .thisEvent)
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Mark as saved so the button flips to "Saved" and is disabled
                    Task { @MainActor in
                        self.meetsVM.markCalendarSaved(for: meet)
                    }
                }
            } catch {
                print("[Calendar] Failed to save event: \(error.localizedDescription)")
            }
        }

        if #available(iOS 17, *) {
            store.requestWriteOnlyAccessToEvents { granted, _ in save(granted) }
        } else {
            store.requestAccess(to: .event) { granted, _ in save(granted) }
        }
    }

    @MainActor
    private func addAllToCalendar() {
        meets.forEach { addToCalendar(meet: $0) }
    }
}

// MARK: - MeetsHeader

private struct MeetsHeader: View {
    let meets: [Meet]
    @Binding var showMap: Bool

    private var hasLocations: Bool {
        meets.contains { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Meets")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(meets.isEmpty ? "No" : "\(meets.count)") upcoming event\(meets.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            if hasLocations {
                HeaderChip(systemName: "map.fill", label: "Map") {
                    showMap = true
                }
            }
        }
    }
}

private struct HeaderChip: View {
    let systemName: String
    let label: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
            action()
        }) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.94 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
    }
}

// MARK: - MeetCard

private struct MeetCard: View {
    let meet: Meet
    @ObservedObject var meetsVM: MeetsViewModel
    let onQRScan: () -> Void
    let onAddToCalendar: () -> Void

    @State private var expanded = false
    @State private var isPressed = false

    private var isRSVPed: Bool { meetsVM.rsvp[meet.id] ?? false }
    private var isCheckedIn: Bool { meetsVM.checkedIn[meet.id] ?? false }
    private var notifyOn: Bool { meetsVM.notifyOn[meet.id] ?? false }
    private var isSavedToCalendar: Bool { meetsVM.calendarSaved[meet.id] ?? false }

    var body: some View {
        VStack(spacing: 0) {
            // --- Main card tap area ---
            Button {
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    expanded.toggle()
                }
            } label: {
                cardBody
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )

            // --- Expanded action row ---
            if expanded {
                actionRow
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isRSVPed ? 0.45 : 0.28),
                                    Color("EmpireMint").opacity(isRSVPed ? 0.35 : 0.08)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    ShimmerMask()
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .opacity(0.4)
                        .blendMode(.screen)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: Card body

    private var cardBody: some View {
        HStack(spacing: 14) {
            // Mint orb with icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color("EmpireMint").opacity(0.9), .clear],
                            center: .center, startRadius: 2, endRadius: 36
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.8), Color.white.opacity(0.1)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: Color("EmpireMint").opacity(0.45), radius: 10, x: 0, y: 4)

                Image(systemName: isCheckedIn ? "checkmark.seal.fill" : "flag.checkered")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isCheckedIn ? .white : Color.black.opacity(0.85))
            }
            .padding(.leading, 4)

            // Text + badge column
            VStack(alignment: .leading, spacing: 5) {
                Text(meet.title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(Color("EmpireMint"))
                    Text(meet.city)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(Color("EmpireMint").opacity(0.8))
                    Text(meet.dateString)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }

                // Badge sits under the metadata rows
                if isCheckedIn {
                    StatusBadge(label: "Checked In", color: Color("EmpireMint"))
                        .padding(.top, 2)
                } else if isRSVPed {
                    StatusBadge(label: "RSVP'd", color: .blue)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            // no badge competing here
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .animation(.spring(response: 0.3), value: expanded)
                .padding(.trailing, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }

    // MARK: Action row

    private var actionRow: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, 14)

            HStack(spacing: 10) {
                // RSVP
                ActionButton(
                    icon: isRSVPed ? "checkmark.circle.fill" : "plus.circle",
                    label: isRSVPed ? "Un-RSVP" : "RSVP",
                    tint: isRSVPed ? Color("EmpireMint") : .white.opacity(0.75),
                    filled: isRSVPed
                ) {
                    Task { await meetsVM.toggleRSVP(for: meet) }
                }

                Divider()
                    .frame(height: 28)
                    .background(Color.white.opacity(0.1))

                // QR Check-In
                ActionButton(
                    icon: isCheckedIn ? "checkmark.seal.fill" : "qrcode.viewfinder",
                    label: isCheckedIn ? "Checked In" : "Check In",
                    tint: isCheckedIn ? Color("EmpireMint") : .white.opacity(0.75),
                    filled: isCheckedIn,
                    disabled: isCheckedIn
                ) {
                    onQRScan()
                }

                Divider()
                    .frame(height: 28)
                    .background(Color.white.opacity(0.1))

                // Notify
                ActionButton(
                    icon: notifyOn ? "bell.fill" : "bell",
                    label: notifyOn ? "Notifying" : "Notify",
                    tint: notifyOn ? .yellow : .white.opacity(0.75),
                    filled: notifyOn
                ) {
                    Task { await meetsVM.toggleNotification(for: meet) }
                }

                Divider()
                    .frame(height: 28)
                    .background(Color.white.opacity(0.1))

                // Calendar
                ActionButton(
                    icon: isSavedToCalendar ? "calendar.badge.checkmark" : "calendar.badge.plus",
                    label: isSavedToCalendar ? "Saved" : "Save",
                    tint: isSavedToCalendar ? Color("EmpireMint") : .white.opacity(0.75),
                    filled: isSavedToCalendar,
                    disabled: isSavedToCalendar
                ) {
                    onAddToCalendar()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let icon: String
    let label: String
    let tint: Color
    let filled: Bool
    var disabled: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            guard !disabled else { return }
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(filled ? tint : tint)
                    .scaleEffect(pressed ? 0.85 : 1)
                    .animation(.spring(response: 0.2), value: pressed)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(filled ? tint : .white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.55 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(Capsule().stroke(color.opacity(0.45), lineWidth: 0.8))
            )
    }
}

// MARK: - QR Scan Flow

struct QRScanFlow: View {
    let meet: Meet?
    let onCode: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                QRCheckInView(onCode: onCode, onCancel: onCancel)
                    .ignoresSafeArea()

                // Bottom HUD
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // Meet label
                        VStack(spacing: 6) {
                            if let meet {
                                Text("Scanning for")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                                Text(meet.title)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            Text("Point camera at your event QR code")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.45))
                        }

                        // Demo QR pill — remove before App Store submission
                        if let meet {
                            Button {
                                let gen = UIImpactFeedbackGenerator(style: .medium)
                                gen.impactOccurred()
                                onCode(meet.id.uuidString)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "ant.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Demo QR")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.orange)
                                        .shadow(color: Color.orange.opacity(0.5), radius: 10, y: 4)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }

                // Finder square overlay
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color("EmpireMint"), lineWidth: 2.5)
                    .frame(width: 220, height: 220)
                    .shadow(color: Color("EmpireMint").opacity(0.5), radius: 12)
            }
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(20)
                }
            }
        }
    }
}

// MARK: - Meets Map Sheet

private struct MeetsMapSheet: View {
    let meets: [Meet]
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition = .automatic

    private var annotations: [MeetAnnotation] {
        meets.compactMap { meet in
            guard let lat = meet.latitude, let lon = meet.longitude else { return nil }
            return MeetAnnotation(
                meet: meet,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
            )
        }
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                ForEach(annotations) { ann in
                    Annotation(ann.meet.city, coordinate: ann.coordinate) {
                        MeetMapPin(title: ann.meet.city)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Meet Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("EmpireMint"))
                }
            }
            .onAppear { fitCamera() }
        }
        .preferredColorScheme(.dark)
    }

    private func fitCamera() {
        guard !annotations.isEmpty else { return }
        let lats = annotations.map { $0.coordinate.latitude }
        let lons = annotations.map { $0.coordinate.longitude }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  max((maxLat - minLat) * 1.5, 0.5),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.5)
        )
        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}

private struct MeetAnnotation: Identifiable {
    let id = UUID()
    let meet: Meet
    let coordinate: CLLocationCoordinate2D
}

private struct MeetMapPin: View {
    let title: String
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color("EmpireMint"))
                    .frame(width: 36, height: 36)
                    .shadow(color: Color("EmpireMint").opacity(0.6), radius: 8)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.75)))
        }
    }
}

// MARK: - Check-In Success View

struct CheckInSuccessView: View {
    let meetTitle: String
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var checkScale: CGFloat = 0.3
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0.8

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color("EmpireMint").opacity(0.25), .clear],
                center: .center, startRadius: 20, endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Animated checkmark orb
                ZStack {
                    // Pulse ring
                    Circle()
                        .stroke(Color("EmpireMint").opacity(ringOpacity), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)
                        .animation(
                            .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                            value: ringScale
                        )

                    // Outer glow
                    Circle()
                        .fill(Color("EmpireMint").opacity(0.15))
                        .frame(width: 120, height: 120)
                        .blur(radius: 16)

                    // Main orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color("EmpireMint"), Color("EmpireMint").opacity(0.6)],
                                center: .topLeading, startRadius: 10, endRadius: 60
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: Color("EmpireMint").opacity(0.6), radius: 24, y: 8)

                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.black)
                        .scaleEffect(checkScale)
                }
                .scaleEffect(scale)
                .opacity(opacity)

                // Text
                VStack(spacing: 12) {
                    Text("Checked In!")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text(meetTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color("EmpireMint"))

                    Text("You're on the list. Welcome to the meet.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(opacity)

                Spacer()

                // Dismiss button
                Button(action: onDismiss) {
                    Text("Let's Go")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color("EmpireMint"))
                                .shadow(color: Color("EmpireMint").opacity(0.5), radius: 12, y: 4)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .opacity(opacity)
            }
        }
        .onAppear {
            // Staggered entrance
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                scale = 1
                checkScale = 1
                opacity = 1
            }
            // Pulse ring expands and fades
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                ringScale = 1.6
                ringOpacity = 0
            }
        }
    }
}

// MARK: - Effects / Utils

private struct ShimmerMask: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color.white.opacity(0.3), location: 0.45),
                    .init(color: .clear, location: 0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geo.size.width)
            .offset(x: -geo.size.width + phase * (geo.size.width * 2))
            .onAppear {
                withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ParallaxEffect: ViewModifier {
    let y: CGFloat
    let strength: CGFloat

    func body(content: Content) -> some View {
        let offset = (y / 200).clamped(to: -1...1) * strength
        return content.offset(y: offset)
    }
}

private struct OffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private extension Comparable where Self: Strideable, Self.Stride: SignedNumeric {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    MeetsView()
        .preferredColorScheme(.dark)
}
