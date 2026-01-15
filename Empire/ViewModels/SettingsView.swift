import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var enableHaptics: Bool = true
    @State private var darkMode: Bool = true
    @State private var notificationsEnabled: Bool = true
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
                                GlassRow(icon: "person.crop.circle", title: displayName, subtitle: "Signed in")
                            }
                            SettingsGlassCard {
                                GlassButtonRow(icon: "person.crop.circle.badge.gearshape", title: "Manage Account") {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    showManageAccount = true
                                }
                            }
                        }
                        settingsSection(title: "Appearance") {
                            SettingsGlassCard {
                                ToggleRow(icon: "moon.fill", title: "Dark Mode", isOn: $darkMode)
                            }
                        }
                        settingsSection(title: "Notifications") {
                            SettingsGlassCard {
                                ToggleRow(icon: "bell.badge.fill", title: "Enable Notifications", isOn: $notificationsEnabled)
                            }
                        }
                        settingsSection(title: "About") {
                            SettingsGlassCard {
                                GlassRow(icon: "info.circle.fill", title: "Version", subtitle: appVersion)
                            }
                            SettingsGlassCard {
                                GlassRow(icon: "link", title: "Website", subtitle: "empire.example")
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
            .overlay(ShimmerMask().clipShape(RoundedRectangle(cornerRadius: 18)).opacity(0.35))
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
    var destructive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: icon).foregroundStyle(destructive ? .red : Color("EmpireMint")))
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                Text(title)
                    .foregroundStyle(destructive ? .red : .white)
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

private struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var body: some View {
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
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color("EmpireMint"))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}

private struct ShimmerMask: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        LinearGradient(gradient: Gradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .white.opacity(0.25), location: 0.45),
            .init(color: .clear, location: 0.9)
        ]), startPoint: .topLeading, endPoint: .bottomTrailing)
        .scaleEffect(x: 1.6)
        .offset(x: -120 + phase * 240)
        .onAppear { withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) { phase = 1 } }
        .blendMode(.screen)
        .opacity(0.5)
        .allowsHitTesting(false)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
