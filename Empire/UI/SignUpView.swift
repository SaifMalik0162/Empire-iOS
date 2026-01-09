import SwiftUI

struct SignUpView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @Environment(\.dismiss) private var dismiss

    @State private var animateGradient = false

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var body: some View {
        ZStack {
            animatedBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 3)
                        Image("AppIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    }

                    Text("Create your account")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Join us in a few taps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Fields
                VStack(spacing: 16) {
                    Group {
                        TextField("Full name", text: $name)
                            .textContentType(.name)
                            .autocapitalization(.words)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

                    Group {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

                    // Password
                    Group {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(.newPassword)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        HStack {
                            Spacer()
                            Button {
                                withAnimation {
                                    showPassword.toggle()
                                }
                            } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.accentColor.opacity(0.7))
                            }
                            .padding(.trailing, 12)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

                    // Confirm Password
                    Group {
                        if showConfirmPassword {
                            TextField("Confirm password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                        } else {
                            SecureField("Confirm password", text: $confirmPassword)
                                .textContentType(.newPassword)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        HStack {
                            Spacer()
                            Button {
                                withAnimation {
                                    showConfirmPassword.toggle()
                                }
                            } label: {
                                Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.accentColor.opacity(0.7))
                            }
                            .padding(.trailing, 12)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }

                // Create Account Button
                Button {
                    // Action for create account - no actual action required here
                } label: {
                    Text("Create Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor))
                        .foregroundColor(.white)
                        .shadow(color: Color.accentColor.opacity(0.6), radius: 10, x: 0, y: 5)
                }
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1 : 0.55)

                // Footnote
                Text("By creating an account you agree to our Terms of Service and Privacy Policy.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // Secondary Button
                Button {
                    dismiss()
                } label: {
                    Text("Already have an account? Log In")
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(30)
            .frame(maxWidth: 450)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 20)

            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                            .shadow(radius: 4)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }

    private var animatedBackground: some View {
        let gradientColors1 = [Color(hex: 0xFF6B6B), Color(hex: 0xFFD93D)]
        let gradientColors2 = [Color(hex: 0x4ECDC4), Color(hex: 0x556270)]

        return LinearGradient(
            colors: animateGradient ? gradientColors1 : gradientColors2,
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animateGradient)
        .onAppear {
            animateGradient.toggle()
        }
    }
}

// MARK: - Color Hex Helper
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

#Preview {
    SignUpView()
        .preferredColorScheme(.dark)
}
