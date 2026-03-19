import SwiftUI
import PhotosUI

struct ManageAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var tempName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isSavingName = false
    @State private var isUploadingAvatar = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
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
                                    saveDisplayName()
                                } label: {
                                    Text(isSavingName ? "Saving..." : "Save")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(.ultraThinMaterial))
                                        .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                                .disabled(isSavingName)

                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.9))
                                }

                                if let successMessage {
                                    Text(successMessage)
                                        .font(.caption)
                                        .foregroundStyle(.green.opacity(0.95))
                                }
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
                                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                        Text(isUploadingAvatar ? "Uploading..." : "Upload New Avatar")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Capsule().fill(.ultraThinMaterial))
                                            .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                            .foregroundStyle(.white)
                                    }
                                    .disabled(isUploadingAvatar)
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
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            uploadAvatar(from: item)
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

    private var emailDisplay: String {
        if let u = authViewModel.currentUser, !u.email.isEmpty { return u.email }
        return ""
    }

    private var avatarView: some View {
        Group {
            if let urlString = authViewModel.avatarPublicURLString(from: authViewModel.currentUser?.avatarPath),
               let avatarURL = URL(string: urlString) {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().tint(Color("EmpireMint"))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(Color("EmpireMint"))
                            .padding(8)
                    @unknown default:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(Color("EmpireMint"))
                            .padding(8)
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(Color("EmpireMint"))
                    .padding(8)
            }
        }
        .frame(width: 56, height: 56)
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }

    private func saveDisplayName() {
        let normalized = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            errorMessage = "Display name cannot be empty."
            successMessage = nil
            return
        }

        isSavingName = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await authViewModel.updateUsername(normalized)
                await MainActor.run {
                    tempName = displayName
                    isSavingName = false
                    successMessage = "Display name updated."
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isSavingName = false
                    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = message.isEmpty ? "Could not update display name." : message
                    successMessage = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func uploadAvatar(from item: PhotosPickerItem) {
        isUploadingAvatar = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw NSError(domain: "ManageAccountView", code: 1)
                }
                try await authViewModel.updateAvatar(imageData: data)
                await MainActor.run {
                    isUploadingAvatar = false
                    successMessage = "Avatar updated."
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isUploadingAvatar = false
                    errorMessage = "Could not upload avatar."
                    successMessage = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
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
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(fmod(t / 3.5, 1.0))

            Rectangle()
                .fill(Color.white.opacity(0.0))
                .overlay(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: max(0, phase - 0.25)),
                            .init(color: .white.opacity(0.25), location: phase),
                            .init(color: .clear, location: min(1, phase + 0.25))
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .opacity(0.5)
                .compositingGroup()
                .drawingGroup(opaque: false, colorMode: .linear)
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    ManageAccountView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
