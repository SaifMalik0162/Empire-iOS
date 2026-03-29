import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isSending = false
    @State private var showValidation = false
    @State private var successMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        AuthScreen {
            ZStack(alignment: .topTrailing) {
                AuthPanel {
                    VStack(spacing: 16) {
                        AuthHeader(
                            title: "Reset your password",
                            subtitle: "Enter your email to get a reset link.",
                            logoSize: 88
                        )

                        VStack(spacing: 12) {
                            AuthField(
                                title: "Email",
                                icon: "paperplane.fill",
                                text: $email,
                                contentType: .emailAddress,
                                keyboardType: .emailAddress
                            )

                            if showValidation && email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                AuthMessage(text: "Please enter your email.", tone: .error)
                            }

                            if let errorMessage {
                                AuthMessage(text: errorMessage, tone: .error)
                            }

                            if let successMessage {
                                AuthMessage(text: successMessage, tone: .success)
                            }
                        }

                        AuthPrimaryButton(
                            title: isSending ? "Sending link..." : "Send Reset Link",
                            isLoading: isSending,
                            isDisabled: isSending
                        ) {
                            sendResetLink()
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Back to Login")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(EmpireTheme.mintCore)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(AuthPalette.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(14)
            }
        }
    }

    private func sendResetLink() {
        showValidation = true
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }

        isSending = true
        successMessage = nil
        errorMessage = nil

        Task {
            do {
                try await authViewModel.sendPasswordReset(email: trimmedEmail)
                await MainActor.run {
                    isSending = false
                    successMessage = "If an account exists, a reset link was sent to \(trimmedEmail)."
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = message.isEmpty ? "Failed to send reset link. Try again." : message
                }
            }
        }
    }
}

struct PasswordRecoveryView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var isFormValid: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            AuthScreen {
                ScrollView(showsIndicators: false) {
                    AuthPanel {
                        VStack(spacing: 20) {
                        AuthHeader(
                            title: "Choose a new password",
                            subtitle: "Finish recovery with a password that feels strong and easy to remember.",
                            logoSize: 104
                        )

                        VStack(spacing: 14) {
                            AuthField(
                                title: "New password",
                                icon: "lock.rotation",
                                text: $newPassword,
                                contentType: .newPassword,
                                isSecure: true,
                                revealSecureText: showNewPassword,
                                onToggleSecure: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showNewPassword.toggle()
                                    }
                                }
                            )

                            AuthField(
                                title: "Confirm password",
                                icon: "checkmark.shield.fill",
                                text: $confirmPassword,
                                contentType: .newPassword,
                                isSecure: true,
                                revealSecureText: showConfirmPassword,
                                onToggleSecure: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showConfirmPassword.toggle()
                                    }
                                }
                            )

                            if let errorMessage {
                                AuthMessage(text: errorMessage, tone: .error)
                            }

                            if let successMessage {
                                AuthMessage(text: successMessage, tone: .success)
                            }

                            Text("Passwords must be at least 6 characters.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(AuthPalette.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        AuthPrimaryButton(
                            title: isSaving ? "Updating password..." : "Update Password",
                            isLoading: isSaving,
                            isDisabled: isSaving || !isFormValid
                        ) {
                            completePasswordReset()
                        }
                    }
                }
                .padding(.vertical, 8)
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        authViewModel.dismissPasswordRecovery()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func completePasswordReset() {
        guard isFormValid else {
            errorMessage = "Passwords must match and be at least 6 characters."
            successMessage = nil
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await authViewModel.completePasswordReset(newPassword)
                await MainActor.run {
                    isSaving = false
                    successMessage = "Your password was updated. You can continue in the app now."
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = message.isEmpty ? "Could not update your password." : message
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
