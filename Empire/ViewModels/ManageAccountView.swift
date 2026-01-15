import SwiftUI

struct ManageAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var tempName: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        headerCard
                        SettingsGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Account Info")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color("EmpireMint"))
                                GlassRow(icon: "person.crop.circle", title: displayName, subtitle: emailDisplay)
                            }
                        }
                        SettingsGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Edit Display Name")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color("EmpireMint"))
                                TextField("Display Name", text: $tempName)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                    .foregroundStyle(.white)
                                Button {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    // TODO: Wire to backend to save display name
                                } label: {
                                    Text("Save")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(.ultraThinMaterial))
                                        .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 2)
                        }
                        SettingsGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Change Avatar")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color("EmpireMint"))
                                HStack(spacing: 12) {
                                    avatarView
                                    Button {
                                        let gen = UIImpactFeedbackGenerator(style: .light)
                                        gen.impactOccurred()
                                        // TODO: Hook up PhotosPicker and upload avatar
                                    } label: {
                                        Text("Upload New Avatar")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Capsule().fill(.ultraThinMaterial))
                                            .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                            .foregroundStyle(.white)
                                    }
                                    .buttonStyle(.plain)
                                    Spacer()
                                }
                            }
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Manage Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { tempName = displayName }
        .preferredColorScheme(.dark)
    }

    private var displayName: String {
        if let u = authViewModel.currentUser {
            if !u.username.isEmpty { return u.username }
            if !u.email.isEmpty { return u.email }
        }
        return "Guest"
    }

    private var emailDisplay: String {
        if let u = authViewModel.currentUser, !u.email.isEmpty { return u.email }
        return ""
    }

    private var headerCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        .blendMode(.screen)
                )
                .shadow(color: Color("EmpireMint").opacity(0.25), radius: 18, y: 8)
                .overlay(ShimmerMask().clipShape(RoundedRectangle(cornerRadius: 24)).opacity(0.45))
            HStack(spacing: 14) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(Color("EmpireMint"))
                            .font(.system(size: 22, weight: .semibold))
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Account")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Manage your profile")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private var avatarView: some View {
        Group {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(Color("EmpireMint"))
                .padding(8)
        }
        .frame(width: 56, height: 56)
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
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
    let subtitle: String

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
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.caption)
                }
            }
            Spacer()
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
    ManageAccountView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
