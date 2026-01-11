import SwiftUI

struct SignUpView:  View {
    @EnvironmentObject var authViewModel: AuthViewModel  // ✅ NEW
    
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @Environment(\.dismiss) private var dismiss

    @State private var animateGradient = false
    @State private var showValidation:  Bool = false
    @State private var isCreating:  Bool = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var body: some View {
        ZStack {
            ZStack {
                EmpireTheme.mintTealGradient(start: animateGradient ? .topLeading : .bottomTrailing,
                                             end: animateGradient ?  .bottomTrailing : .topLeading)
                EmpireTheme.mintTealGradient(start: animateGradient ? .bottomLeading : .topTrailing,
                                             end: animateGradient ? .topTrailing : . bottomLeading)
                    . opacity(0.45)
                    .blendMode(.plusLighter)
            }
            . blur(radius: 8)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 6).repeatForever(autoreverses:  true), value: animateGradient)
            .onAppear {
                animateGradient = true
            }

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 10) {
                    EmpireLogoView(size:  160, style: .tinted(EmpireTheme.mintCore), shimmer: true, parallaxAmount: 0)

                    Text("Create your account")
                        .font(. title)
                        .fontWeight(.semibold)
                        .foregroundColor(. primary)

                    Text("Join us in a few taps")
                        .font(.subheadline)
                        . foregroundColor(.secondary)
                }

                // ✅ Error message display
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(. red)
                        .padding(. horizontal)
                        .padding(.vertical, 8)
                        . background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                        )
                        .transition(.opacity)
                }

                // Fields
                VStack(spacing: 16) {
                    Group {
                        TextField("Full name", text: $name)
                            .textContentType(.name)
                            .autocapitalization(.words)
                    }
                    . padding()
                    . background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(. ultraThinMaterial)
                    )
                    .empireMintGlassStroke(cornerRadius: 16, lineWidth:  1.25)
                    .shadow(color: EmpireTheme.mintCore.opacity(0.1), radius: 6, x: 0, y:  4)
                    .disabled(isCreating)

                    Group {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: . continuous)
                            .fill(. ultraThinMaterial)
                    )
                    .empireMintGlassStroke(cornerRadius: 16, lineWidth:  1.25)
                    .shadow(color: EmpireTheme.mintCore.opacity(0.1), radius: 6, x: 0, y:  4)
                    .disabled(isCreating)

                    if showValidation && username.isEmpty {
                        Text("Please enter a username.")
                            .font(.footnote)
                            .foregroundColor(.red.opacity(0.9))
                    }

                    Group {
                        TextField("Email", text: $email)
                            .textContentType(. emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: . continuous)
                            .fill(. ultraThinMaterial)
                    )
                    .empireMintGlassStroke(cornerRadius: 16, lineWidth:  1.25)
                    .shadow(color: EmpireTheme.mintCore.opacity(0.1), radius: 6, x: 0, y:  4)
                    .disabled(isCreating)

                    if showValidation && email.isEmpty {
                        Text("Please enter your email.")
                            .font(. footnote)
                            .foregroundColor(.red.opacity(0.9))
                    }

                    // Password
                    Group {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textContentType(. newPassword)
                                .autocapitalization(.none)
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(.newPassword)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        HStack {
                            Spacer()
                            Button {
                                withAnimation {
                                    showPassword.toggle()
                                }
                            } label:  {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(EmpireTheme.mintCore.opacity(0.7))
                            }
                            .padding(.trailing, 12)
                            .disabled(isCreating)
                        }
                    )
                    .empireMintGlassStroke(cornerRadius: 16, lineWidth: 1.25)
                    .shadow(color: EmpireTheme.mintCore.opacity(0.1), radius: 6, x: 0, y: 4)
                    .disabled(isCreating)

                    if showValidation && password.count < 6 {
                        Text("Password must be at least 6 characters.")
                            .font(.footnote)
                            .foregroundColor(.red.opacity(0.9))
                    }

                    // Confirm Password
                    Group {
                        if showConfirmPassword {
                            TextField("Confirm password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                        } else {
                            SecureField("Confirm password", text:  $confirmPassword)
                                . textContentType(.newPassword)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius:  16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        HStack {
                            Spacer()
                            Button {
                                withAnimation {
                                    showConfirmPassword.toggle()
                                }
                            } label: {
                                Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(EmpireTheme.mintCore.opacity(0.7))
                            }
                            .padding(. trailing, 12)
                            .disabled(isCreating)
                        }
                    )
                    .empireMintGlassStroke(cornerRadius: 16, lineWidth: 1.25)
                    .shadow(color: EmpireTheme.mintCore.opacity(0.1), radius: 6, x: 0, y: 4)
                    .disabled(isCreating)

                    if showValidation && confirmPassword != password {
                        Text("Passwords don't match.")
                            .font(.footnote)
                            . foregroundColor(.red.opacity(0.9))
                    }
                }

                // ✅ UPDATED: Create Account Button
                Button {
                    performSignUp()
                } label: {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isCreating ? "Creating..." : "Create Account")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentColor)
                            .empireMintShadow(radius: 10, x: 0, y: 5, opacity: 0.6)
                    )
                    .foregroundColor(.white)
                }
                .disabled(!isFormValid || isCreating)
                .opacity(isCreating ? 0.8 : (isFormValid ? 1 : 0.55))

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
                    Text("Already have an account?  Log In")
                        .fontWeight(. semibold)
                        .foregroundColor(.accentColor)
                }
                .disabled(isCreating)
            }
            .padding(30)
            .frame(maxWidth: 450)
            .background(
                RoundedRectangle(cornerRadius: 32, style: . continuous)
                    .fill(. ultraThinMaterial)
            )
            .empireMintGlassStroke(cornerRadius:  32, lineWidth: 1.5)
            .shadow(color: EmpireTheme.mintCore.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)

            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark. circle.fill")
                            . font(.system(size: 28, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                            .shadow(radius: 4)
                    }
                    .padding()
                    .disabled(isCreating)
                }
                Spacer()
            }
        }
    }

    // ✅ UPDATED: Backend signup function with AuthViewModel
    private func performSignUp() {
        let isValid = !name.isEmpty &&
                      !username.isEmpty &&
                      !email.isEmpty &&
                      email.contains("@") &&
                      password.count >= 6 &&
                      password == confirmPassword
        
        showValidation = !isValid
        guard isValid else { return }
        
        errorMessage = nil
        isCreating = true
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            do {
                print("🔄 Signing up:  \(email), username: \(username)")
                
                try await authViewModel.register(
                    email: email,
                    password: password,
                    username: username
                )
                
                await MainActor.run {
                    isCreating = false
                    
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)
                    
                    // Dismiss signup sheet - EmpireApp will automatically show main app
                    dismiss()
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    isCreating = false
                    
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "An unexpected error occurred"
                    isCreating = false
                    
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
            }
        }
    }

    private var animatedBackground: some View {
        EmpireTheme.mintDarkGradient(start: animateGradient ? . topLeading : .bottomTrailing,
                                end: animateGradient ? . bottomTrailing : .topLeading)
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
            . sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
