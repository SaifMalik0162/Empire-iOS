import SwiftUI

struct SignUpView: View {
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showValidation = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    private var normalizedEmail: String {
        AuthViewModel.normalizedSignupEmail(email)
    }

    private var hasValidEmail: Bool {
        let trimmed = normalizedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return !parts[0].isEmpty && !parts[1].isEmpty
    }

    private var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        hasValidEmail &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var body: some View {
        AuthScreen {
            ZStack(alignment: .topTrailing) {
                AuthPanel {
                    VStack(spacing: 14) {
                        AuthHeader(
                            title: "Create your Empire account",
                            subtitle: "Create your profile.",
                            logoSize: 84
                        )

                        VStack(spacing: 10) {
                            AuthField(
                                title: "Username",
                                icon: "person.fill",
                                text: $username,
                                contentType: .username
                            )

                            AuthField(
                                title: "Email",
                                icon: "envelope.fill",
                                text: $email,
                                contentType: .emailAddress,
                                keyboardType: .emailAddress
                            )

                            AuthField(
                                title: "Password",
                                icon: "lock.fill",
                                text: $password,
                                contentType: .newPassword,
                                isSecure: true,
                                revealSecureText: showPassword,
                                onToggleSecure: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showPassword.toggle()
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
                        }

                        if showValidation && email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            AuthMessage(text: "Please enter your email address.", tone: .error)
                        } else if showValidation && !hasValidEmail {
                            AuthMessage(text: "Please enter a valid email address.", tone: .error)
                        } else if showValidation && password.count < 6 {
                            AuthMessage(text: "Password must be at least 6 characters.", tone: .error)
                        } else if showValidation && confirmPassword != password {
                            AuthMessage(text: "Passwords don't match.", tone: .error)
                        } else if let errorMessage {
                            AuthMessage(text: errorMessage, tone: .error)
                        }

                        AuthPrimaryButton(
                            title: isCreating ? "Creating account..." : "Create Account",
                            isLoading: isCreating,
                            isDisabled: !isFormValid || isCreating
                        ) {
                            let isValid = isFormValid
                            showValidation = !isValid
                            if isValid {
                                performRegister()
                            }
                        }

                        VStack(spacing: 8) {
                            Text("By creating an account you agree to our Terms of Service and Privacy Policy.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AuthPalette.textMuted)
                                .multilineTextAlignment(.center)

                            Button {
                                dismiss()
                            } label: {
                                Text("Already have an account? Log In")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(EmpireTheme.mintCore)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                closeButton
            }
        }
    }

    private var closeButton: some View {
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

    private func performRegister() {
        guard hasValidEmail else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
                try await authViewModel.register(email: normalizedEmail, password: password, username: normalizedUsername)
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch let error as AuthUserFacingError {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.errorDescription
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.errorDescription
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = message.isEmpty ? "Could not create account. Please try again." : message
                }
            }
        }
    }
}
