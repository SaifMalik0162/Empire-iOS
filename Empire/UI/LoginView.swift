import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showMainApp: Bool = false
    @State private var appleNonce: String = ""

    @EnvironmentObject var authViewModel: AuthViewModel

    // Backend integration
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            ZStack {
                EmpireTheme.mintTealGradient(start: animateGradient ? .topLeading : .bottomTrailing,
                                             end: animateGradient ? .bottomTrailing : .topLeading)
                EmpireTheme.mintTealGradient(start: animateGradient ? .bottomLeading : .topTrailing,
                                             end: animateGradient ? .topTrailing : .bottomLeading)
                    .opacity(0.45)
                    .blendMode(.plusLighter)
            }
            .blur(radius: 8)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: animateGradient)
            .onAppear {
                animateGradient = true
            }
            
            VStack(spacing: 24) {
                
                // Logo
                ZStack {
                    EmpireLogoView(size: 220, style: .tinted(EmpireTheme.mintCore), shimmer: true, parallaxAmount: 0)
                }
                .padding(.bottom, 12)
                .padding(.top, 12)
                
                VStack(spacing: 16) {
                    // Email TextField
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .empireMintGlassStroke(cornerRadius: 16, lineWidth: 1.25)
                        .shadow(color: EmpireTheme.mintCore.opacity(0.1), radius: 6, x: 0, y: 4)
                    
                    // Password field with show/hide toggle
                    ZStack(alignment: .trailing) {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .empireMintGlassStroke(cornerRadius: 16, lineWidth: 1.25)
                        .shadow(color: EmpireTheme.mintCore.opacity(0.1), radius: 6, x: 0, y: 4)
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showPassword.toggle()
                            }
                        } label: {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(EmpireTheme.mintCore.opacity(0.7))
                                .padding(.trailing, 16)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            showForgotPassword = true
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(EmpireTheme.mintCore.opacity(0.85))
                        .font(.footnote)
                    }
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                            .transition(.opacity)
                    }
                }
                
                // Log In Button
                Button {
                    performLogin()
                } label: {
                    Text("Log In")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(EmpireTheme.mintCore)
                        )
                        .empireMintShadow(radius: 10, x: 0, y: 5, opacity: 0.6)
                        .foregroundColor(.white)
                }
                .disabled(isLoading || email.isEmpty || password.count < 6)
                .opacity((isLoading || email.isEmpty || password.count < 6) ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.2), value: isLoading || email.isEmpty || password.count < 6)
                
                // Divider with "or"
                HStack {
                    Divider()
                        .background(EmpireTheme.mintCore.opacity(0.4))
                    Text("or")
                        .foregroundColor(EmpireTheme.mintCore.opacity(0.6))
                        .font(.footnote)
                        .fontWeight(.medium)
                    Divider()
                        .background(EmpireTheme.mintCore.opacity(0.4))
                }
                .padding(.vertical, 8)
                
                SignInWithAppleButton(.signIn) { request in
                    let nonce = randomNonceString()
                    appleNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(EmpireTheme.mintCore.opacity(0.35), lineWidth: 1)
                )
                
                Spacer(minLength: 10)
                
                // Footer HStack
                HStack(spacing: 4) {
                    Text("Don’t have an account?")
                        .foregroundColor(EmpireTheme.mintCore.opacity(0.7))
                        .font(.footnote)
                    Button("Sign Up") {
                        showSignUp = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(EmpireTheme.mintCore)
                }
                .padding(.bottom, 10)
                
            }
            .padding(32)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .empireMintGlassStroke(cornerRadius: 32, lineWidth: 1.5)
            .shadow(color: EmpireTheme.mintCore.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authViewModel)
        }
        .fullScreenCover(isPresented: $showMainApp) {
            EmpireTabView()
                .preferredColorScheme(.dark)
        }
    }
    
    // Backend login function with AuthViewModel
    private func performLogin() {
        isLoading = true
        errorMessage = nil
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            do {
                try await authViewModel.login(email: email, password: password)
                
                await MainActor.run {
                    isLoading = false
                    // No need to navigate - EmpireApp will automatically switch to main app
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    isLoading = false
                    
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
            } catch {
                await MainActor.run {
                    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = message.isEmpty ? "An unexpected error occurred" : message
                    isLoading = false
                    
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private var animatedBackground: some View {
        EmpireTheme.mintDarkGradient(start: animateGradient ? .topLeading : .bottomTrailing,
                                 end: animateGradient ? .bottomTrailing : .topLeading)
            .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: animateGradient)
            .onAppear {
                animateGradient = true
            }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Failed to read Apple credential."
                return
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  !appleNonce.isEmpty else {
                errorMessage = "Failed to process Apple identity token."
                return
            }

            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let suggestedUsername = fullName.isEmpty ? nil : fullName

            performAppleLogin(idToken: idToken, nonce: appleNonce, suggestedUsername: suggestedUsername)
        }
    }

    private func performAppleLogin(idToken: String, nonce: String, suggestedUsername: String?) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authViewModel.loginWithApple(idToken: idToken, nonce: nonce, suggestedUsername: suggestedUsername)
                await MainActor.run {
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = message.isEmpty ? "Apple sign in failed." : message
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms: [UInt8] = Array(repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }

            for random in randoms {
                if remainingLength == 0 {
                    break
                }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .preferredColorScheme(.dark)
    }
}

