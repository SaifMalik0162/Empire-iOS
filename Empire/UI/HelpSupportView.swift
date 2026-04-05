import SwiftUI

struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var authViewModel: AuthViewModel

    private let websiteURL = URL(string: "https://empireconnect.app/")!
    private let supportURL = URL(string: "https://empireconnect.app/support/")!
    private let termsURL = URL(string: "https://empireconnect.app/terms/")!
    private let privacyURL = URL(string: "https://empireconnect.app/privacy/")!
    private let supportEmailAddress = "empireconnectapp@gmail.com"
    private let gmailAppStoreURL = URL(string: "https://apps.apple.com/app/id422689480")!
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        section(title: "Quick Help") {
                            HelpGlassCard {
                                CompactQuickHelp(
                                    items: [
                                        .init(icon: "person.2.fill", title: "Contact Support", action: {
                                            openGmailCompose(
                                                subject: "Empire Connect Support Request",
                                                body: """
                                                Hi Empire Connect Support,

                                                I need help with:

                                                Device:
                                                App version:
                                                Details:
                                                """
                                            )
                                        }),
                                        .init(icon: "bubble.left.and.bubble.right.fill", title: "Submit Feedback", action: {
                                            openGmailCompose(
                                                subject: "Empire Connect Feedback",
                                                body: """
                                                Hi Empire Connect Team,

                                                I wanted to share some feedback:

                                                """
                                            )
                                        }),
                                        .init(icon: "ladybug.fill", title: "Report a Bug", action: {
                                            openGmailCompose(
                                                subject: "Empire Connect Bug Report",
                                                body: """
                                                Hi Empire Connect Team,

                                                I found a bug.

                                                What happened:
                                                What I expected:
                                                Steps to reproduce:
                                                Device:
                                                App version:
                                                """
                                            )
                                        })
                                    ]
                                )
                            }
                        }

                        section(title: "Links") {
                            HelpGlassCard {
                                HelpRow(icon: "questionmark.circle.fill", title: "FAQ") {
                                    openWebsite(supportURL)
                                }
                            }

                            HelpGlassCard {
                                HelpRow(icon: "doc.text.fill", title: "Terms of Service") {
                                    openWebsite(termsURL)
                                }
                            }

                            HelpGlassCard {
                                HelpRow(icon: "hand.raised.fill", title: "Privacy Policy") {
                                    openWebsite(privacyURL)
                                }
                            }

                            HelpGlassCard {
                                HelpWebsiteRow {
                                    openWebsite(websiteURL)
                                }
                            }
                        }

                        section(title: "System Status") {
                            HelpGlassCard {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 10, height: 10)
                                    Text("All systems operational")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                            }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("EmpireMint"))
            VStack(spacing: 8) {
                content()
            }
        }
    }

    private func haptic() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    private func openWebsite(_ url: URL) {
        haptic()
        openURL(url)
    }

    private func openGmailCompose(subject: String, body: String) {
        haptic()

        var appComponents = URLComponents()
        appComponents.scheme = "googlegmail"
        appComponents.host = "co"
        appComponents.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
            URLQueryItem(name: "to", value: supportEmailAddress)
        ]

        guard let gmailAppURL = appComponents.url else {
            openWebsite(supportURL)
            return
        }

        openURL(gmailAppURL) { accepted in
            if !accepted {
                openURL(gmailAppStoreURL)
            }
        }
    }
}

private struct HelpGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
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

private struct HelpRow: View {
    let icon: String
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: icon).foregroundStyle(Color("EmpireMint")))
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                Text(title)
                    .foregroundStyle(.white)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct HelpWebsiteRow: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "link").foregroundStyle(Color("EmpireMint")))
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Website")
                        .foregroundStyle(.white)
                        .font(.subheadline.weight(.semibold))
                    Text("empireconnect.app")
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.caption)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("Open")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct QuickHelpRow: View {
    let icon: String
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(EmpireTheme.mintAdaptive)
                }
                .frame(width: 40, height: 40)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(height: 52)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct QuickHelpItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let action: () -> Void
}

private struct CompactQuickHelp: View {
    let items: [QuickHelpItem]

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
            ForEach(items) { item in
                CompactQuickHelpPill(icon: item.icon, title: item.title, action: item.action)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct CompactQuickHelpPill: View {
    let icon: String
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .shadow(color: EmpireTheme.mintCore.opacity(0.15), radius: 6, y: 2)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(EmpireTheme.mintAdaptive)
                }
                .frame(width: 36, height: 36)

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(EmpireTheme.mintCore.opacity(0.06), lineWidth: 1)
                        .blur(radius: 1)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .frame(minHeight: 72)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(EmpireTheme.mintCore.opacity(0.12), lineWidth: 0.5)
                .blendMode(.screen)
        )
    }
}


#Preview {
    HelpSupportView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
