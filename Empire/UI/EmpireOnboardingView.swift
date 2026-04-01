import SwiftUI
import UserNotifications

struct EmpireOnboardingView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pageIndex = 0
    @State private var glowShift = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingNotifications = false

    private let pages: [EmpireOnboardingPage] = [
        .feature(
            .init(
                kicker: "WELCOME TO EMPIRE CONNECT",
                title: "Your garage, your feed, your meets.",
                body: "Set up your build, post your moments, and keep up with the Empire scene without any clutter.",
                accent: Color("EmpireMint"),
                symbol: "steeringwheel",
                rows: [
                    .init(title: "Garage", subtitle: "Build cards, stage setup, specs, and photos that make your profile feel complete.", icon: "car.fill"),
                    .init(title: "Feed", subtitle: "Post updates, discover local builds, and keep up with what the community is sharing.", icon: "rectangle.stack.fill"),
                    .init(title: "Meets", subtitle: "Save events, get reminders, and check in quickly when you arrive.", icon: "mappin.and.ellipse")
                ]
            )
        ),
        .permission(
            .init(
                kicker: "STAY IN THE LOOP",
                title: "Turn on notifications.",
                body: "Get meet reminders and important Empire updates without having to keep checking the app.",
                accent: Color("EmpireMint"),
                symbol: "bell.badge.fill",
                helperText: "Calendar and camera access are requested later, only when you actually use those features."
            )
        )
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background

                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        EmpireOnboardingPageView(
                            page: page,
                            notificationStatus: notificationStatus,
                            isRequestingNotifications: isRequestingNotifications,
                            isPermissionPage: index == pages.count - 1,
                            onEnableNotifications: handlePrimaryAction,
                            onSkip: completeOnboarding
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, max(proxy.safeAreaInsets.top + 10, 26))
                        .padding(.bottom, index == pages.count - 1 ? 126 : 162)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(6, proxy.safeAreaInsets.bottom - 2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .ignoresSafeArea()
            .task {
                await refreshNotificationStatus()
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                    glowShift.toggle()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.97)], startPoint: .top, endPoint: .bottom)

            RadialGradient(
                colors: [Color("EmpireMint").opacity(0.18), .clear],
                center: .top,
                startRadius: 24,
                endRadius: 320
            )

            Circle()
                .fill(currentAccent.opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 72)
                .offset(x: glowShift ? -115 : 95, y: -230)
        }
        .ignoresSafeArea()
    }

    private var currentAccent: Color {
        switch pages[pageIndex] {
        case .feature(let page): return page.accent
        case .permission(let page): return page.accent
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == pageIndex ? currentAccent : Color.white.opacity(0.18))
                        .frame(width: index == pageIndex ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: pageIndex)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, isPermissionPage ? 2 : 2)

            if !isPermissionPage {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        pageIndex += 1
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [currentAccent, currentAccent.opacity(0.72)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var isPermissionPage: Bool {
        if case .permission = pages[pageIndex] { return true }
        return false
    }

    private func handlePrimaryAction() {
        if isPermissionPage {
            Task { await requestNotificationsIfNeeded() }
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                pageIndex += 1
            }
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func requestNotificationsIfNeeded() async {
        guard !isRequestingNotifications else { return }
        isRequestingNotifications = true
        defer { isRequestingNotifications = false }

        switch notificationStatus {
        case .notDetermined:
            do {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                break
            }
            await refreshNotificationStatus()
            completeOnboarding()
        default:
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        authViewModel.completeOnboarding()
        dismiss()
    }
}

private struct EmpireOnboardingPageView: View {
    let page: EmpireOnboardingPage
    let notificationStatus: UNAuthorizationStatus
    let isRequestingNotifications: Bool
    let isPermissionPage: Bool
    let onEnableNotifications: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            switch page {
            case .feature(let featurePage):
                featureContent(featurePage)
            case .permission(let permissionPage):
                permissionContent(permissionPage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func featureContent(_ page: EmpireFeatureOnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            minimalHero(symbol: page.symbol, accent: page.accent)
            pageCopy(kicker: page.kicker, title: page.title, body: page.body, accent: page.accent)

            VStack(spacing: 10) {
                ForEach(page.rows) { row in
                    EmpireOnboardingRow(row: row, accent: page.accent)
                }
            }
        }
        .padding(.top, 2)
    }

    private func permissionContent(_ page: EmpirePermissionOnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            minimalHero(symbol: page.symbol, accent: page.accent)

            pageCopy(kicker: page.kicker, title: page.title, body: page.body, accent: page.accent)

            VStack(alignment: .leading, spacing: 14) {
                EmpirePermissionPreviewCard(accent: page.accent)

                Text(page.helperText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                VStack(spacing: 10) {
                    Button(action: onEnableNotifications) {
                        HStack(spacing: 10) {
                            if isRequestingNotifications {
                                ProgressView()
                                    .tint(.black.opacity(0.82))
                            }
                            Text(primaryPermissionLabel)
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [page.accent, page.accent.opacity(0.72)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequestingNotifications)

                    Button("Not Now", action: onSkip)
                        .buttonStyle(.plain)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.055), Color.white.opacity(0.025)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [page.accent.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        }
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Empire Connect Tour")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                Text("Set up your experience")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Button("Skip", action: onSkip)
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
        }
        .offset(y: isPermissionPage ? 14 : 0)
    }

    private func minimalHero(symbol: String, accent: Color) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.15))
                .frame(width: 140, height: 140)
                .blur(radius: 28)

            Circle()
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .frame(width: 106, height: 106)
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                .overlay(
                    Circle()
                        .stroke(accent.opacity(0.10), lineWidth: 8)
                        .blur(radius: 10)
                )

            Image(systemName: symbol)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
    }

    private func pageCopy(kicker: String, title: String, body: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kicker)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(accent)

            Text(title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1)

            Text(body)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primaryPermissionLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Continue"
        case .denied:
            return "Continue"
        case .notDetermined:
            return "Allow Notifications"
        @unknown default:
            return "Continue"
        }
    }
}

private struct EmpireOnboardingRow: View {
    let row: EmpireOnboardingRowModel
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Image(systemName: row.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(row.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.075), Color.white.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.10), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.plusLighter)
        }
    }
}

private struct EmpirePermissionPreviewCard: View {
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("“Empire Connect” Would Like to Send You Notifications")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Notifications may include meet reminders, updates, and important activity.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                permissionButton(title: "Allow", accent: accent, emphasized: true)
                permissionButton(title: "Don’t Allow", accent: accent, emphasized: false)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.40))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.36), radius: 24, y: 12)
    }

    private func permissionButton(title: String, accent: Color, emphasized: Bool) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(emphasized ? .white : .white.opacity(0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(emphasized ? accent.opacity(0.55) : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(emphasized ? accent.opacity(0.72) : Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private enum EmpireOnboardingPage {
    case feature(EmpireFeatureOnboardingPage)
    case permission(EmpirePermissionOnboardingPage)
}

private struct EmpireFeatureOnboardingPage {
    let kicker: String
    let title: String
    let body: String
    let accent: Color
    let symbol: String
    let rows: [EmpireOnboardingRowModel]
}

private struct EmpirePermissionOnboardingPage {
    let kicker: String
    let title: String
    let body: String
    let accent: Color
    let symbol: String
    let helperText: String
}

private struct EmpireOnboardingRowModel: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
}
