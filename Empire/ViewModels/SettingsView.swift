import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var pushNotifications: PushNotificationsManager
    @State private var enableHaptics: Bool = true
    @State private var reduceMotion: Bool = false
    @State private var showManageAccount: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        settingsSection(title: "Account") {
                            SettingsGlassCard {
                                HStack(spacing: 12) {
                                    // Left: account info row visuals
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 36, height: 36)
                                            .overlay(Image(systemName: "person.crop.circle").foregroundStyle(Color("EmpireMint")))
                                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(displayName)
                                                .foregroundStyle(.white)
                                                .font(.subheadline.weight(.semibold))
                                            Text("Signed in")
                                                .foregroundStyle(.white.opacity(0.7))
                                                .font(.caption)
                                        }
                                    }
                                    Spacer()
                                    // Right: Manage Account action
                                    Button {
                                        let gen = UIImpactFeedbackGenerator(style: .light)
                                        gen.impactOccurred()
                                        showManageAccount = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text("Manage Account")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(.ultraThinMaterial))
                                        .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        settingsSection(title: "Experience") {
                            SettingsGlassCard {
                                GlassButtonRow(icon: "sparkles.rectangle.stack.fill", title: "Replay App Tour", subtitle: "View the feature walkthrough again", trailingAccessory: (text: "Open", systemImage: "")) {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        authViewModel.replayOnboarding()
                                    }
                                }
                            }
                        }
                        settingsSection(title: "Notifications") {
                            SettingsGlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 36, height: 36)
                                            .overlay(Image(systemName: "bell.badge.fill").foregroundStyle(Color("EmpireMint")))
                                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Push Notifications")
                                                .foregroundStyle(.white)
                                                .font(.subheadline.weight(.semibold))
                                            Text(pushNotifications.authorizationSummary)
                                                .foregroundStyle(statusColor)
                                                .font(.caption.weight(.semibold))
                                        }

                                        Spacer()

                                        Button {
                                            let gen = UIImpactFeedbackGenerator(style: .light)
                                            gen.impactOccurred()
                                            handleNotificationButtonTap()
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(notificationActionTitle)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)
                                                    .fixedSize(horizontal: true, vertical: false)
                                                Image(systemName: notificationActionSystemImage)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(.ultraThinMaterial))
                                            .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if let notificationSummaryText {
                                        Text(notificationSummaryText)
                                            .foregroundStyle(.white.opacity(0.66))
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }

                                    LazyVGrid(
                                        columns: [
                                            GridItem(.flexible(), spacing: 10),
                                            GridItem(.flexible(), spacing: 10)
                                        ],
                                        spacing: 10
                                    ) {
                                        CompactNotificationToggleTile(
                                            icon: "heart.fill",
                                            title: "Likes",
                                            subtitle: "Build likes",
                                            isOn: notificationBinding(for: \.likes)
                                        )
                                        .disabled(pushNotifications.authorizationStatus == .denied || pushNotifications.isSyncingPreferences)

                                        CompactNotificationToggleTile(
                                            icon: "bubble.left.and.bubble.right.fill",
                                            title: "Comments",
                                            subtitle: "New replies",
                                            isOn: notificationBinding(for: \.comments)
                                        )
                                        .disabled(pushNotifications.authorizationStatus == .denied || pushNotifications.isSyncingPreferences)

                                        CompactNotificationToggleTile(
                                            icon: "person.2.fill",
                                            title: "Follows",
                                            subtitle: "Profile activity",
                                            isOn: notificationBinding(for: \.follows)
                                        )
                                        .disabled(pushNotifications.authorizationStatus == .denied || pushNotifications.isSyncingPreferences)

                                        CompactNotificationToggleTile(
                                            icon: "mappin.and.ellipse",
                                            title: "Meets",
                                            subtitle: "Updates & reminders",
                                            isOn: notificationBinding(for: \.meets)
                                        )
                                        .disabled(pushNotifications.authorizationStatus == .denied || pushNotifications.isSyncingPreferences)
                                    }

                                    if pushNotifications.isSyncingPreferences {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(Color("EmpireMint"))
                                            Text("Syncing notification preferences…")
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.68))
                                        }
                                    }

                                    if let registrationError = pushNotifications.lastRegistrationError,
                                       !registrationError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(registrationError)
                                            .font(.caption2)
                                            .foregroundStyle(.red.opacity(0.9))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        settingsSection(title: "About") {
                            SettingsGlassCard {
                                GlassButtonRow(icon: "link", title: "Website", subtitle: "empireontario.shop", trailingAccessory: (text: "Open", systemImage: "")) {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    if let url = URL(string: "https://empireontario.shop/") {
                                        openURL(url)
                                    }
                                }
                            }
                            SettingsGlassCard {
                                GlassRow(icon: "info.circle.fill", title: "Version", subtitle: appVersion)
                            }
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showManageAccount) {
            ManageAccountView()
                .environmentObject(authViewModel)
                .preferredColorScheme(.dark)
        }
        .task {
            await pushNotifications.handleAuthStateChanged(user: authViewModel.currentUser)
        }
        .preferredColorScheme(.dark)
    }

    private var displayName: String {
        if let u = authViewModel.currentUser {
            if !u.username.isEmpty { return u.username }
            if !u.email.isEmpty { return u.email }
        }
        return "Guest"
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }

    private var statusColor: Color {
        switch pushNotifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return Color("EmpireMint")
        case .denied:
            return .red.opacity(0.9)
        case .notDetermined:
            return .white.opacity(0.7)
        @unknown default:
            return .white.opacity(0.7)
        }
    }

    private var notificationActionTitle: String {
        switch pushNotifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "App Settings"
        case .denied:
            return "App Settings"
        case .notDetermined:
            return "Enable Alerts"
        @unknown default:
            return "App Settings"
        }
    }

    private var notificationActionSystemImage: String {
        switch pushNotifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "arrow.up.right.square"
        case .denied:
            return "gearshape.fill"
        case .notDetermined:
            return "bell.fill"
        @unknown default:
            return "arrow.up.right.square"
        }
    }

    private var notificationSummaryText: String? {
        switch pushNotifications.authorizationStatus {
        case .authorized:
            return nil
        case .provisional, .ephemeral:
            return "Notifications are limited. Fine-tune alerts here or fully enable them in iOS Settings."
        case .denied:
            return "Notifications are off in iOS Settings."
        case .notDetermined:
            return "Turn notifications on for activity and meet updates."
        @unknown default:
            return "Manage Empire activity alerts."
        }
    }

    private func handleNotificationButtonTap() {
        switch pushNotifications.authorizationStatus {
        case .notDetermined:
            Task { await pushNotifications.requestAuthorizationAndRegister() }
        default:
            pushNotifications.openSystemNotificationSettings()
        }
    }

    private func notificationBinding(for keyPath: WritableKeyPath<PushNotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: {
                pushNotifications.preferences[keyPath: keyPath]
            },
            set: { newValue in
                var updated = pushNotifications.preferences
                updated[keyPath: keyPath] = newValue
                Task {
                    await pushNotifications.updatePreferences(updated)
                }
            }
        )
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("EmpireMint"))
            VStack(spacing: 10) {
                content()
            }
        }
    }
}

private struct SettingsGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .blendMode(.screen)
            )
            .shadow(color: Color("EmpireMint").opacity(0.22), radius: 14, y: 6)
    }
}

private struct GlassRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: icon).foregroundStyle(Color("EmpireMint")))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white)
                    .font(.subheadline.weight(.semibold))
                if let subtitle { Text(subtitle).foregroundStyle(.white.opacity(0.7)).font(.caption) }
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}

private struct GlassButtonRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var destructive: Bool = false
    var trailingAccessory: (text: String, systemImage: String)? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: icon).foregroundStyle(destructive ? .red : Color("EmpireMint")))
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(destructive ? .red : .white)
                        .font(.subheadline.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.caption)
                    }
                }
                Spacer()
                if let trailingAccessory {
                    HStack(spacing: 6) {
                        Text(trailingAccessory.text)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        if !trailingAccessory.systemImage.isEmpty {
                            Image(systemName: trailingAccessory.systemImage)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: icon).foregroundStyle(Color("EmpireMint")))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white)
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .foregroundStyle(.white.opacity(0.68))
                        .font(.caption)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color("EmpireMint"))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}

private struct CompactNotificationToggleTile: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 30, height: 30)
                    .overlay(Image(systemName: icon).foregroundStyle(Color("EmpireMint")))
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))

                Spacer(minLength: 0)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(Color("EmpireMint"))
                    .scaleEffect(0.82)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .foregroundStyle(.white.opacity(0.6))
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}


#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .environmentObject(PushNotificationsManager.shared)
        .preferredColorScheme(.dark)
}
