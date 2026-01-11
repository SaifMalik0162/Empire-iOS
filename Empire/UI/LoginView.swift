import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel  // ✅ NEW
    
    @State private var email: String = ""
    @State private var password:  String = ""
    @State private var showPassword:  Bool = false
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    
    // ✅ NEW: Backend integration
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            ZStack {
                EmpireTheme.mintTealGradient(start: animateGradient ?  . topLeading : .bottomTrailing,
                                             end: animateGradient ? .bottomTrailing : .topLeading)
                EmpireTheme.mintTealGradient(start: animateGradient ? .bottomLeading : .topTrailing,
                                             end: animateGradient ? .topTrailing :  .bottomLeading)
                    .opacity(0.45)
                    .blendMode(.plusLighter)
            }
            . blur(radius: 8)
            .ignoresSafeArea()
            . animation(.easeInOut(duration: 6).repeatForever(autoreverses:  true), value: animateGradient)
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
                                .fill(. ultraThinMaterial)
                        )
                        .empireMintGlassStroke(cornerRadius: 16, lineWidth: 1.25)
                        .shadow(color: EmpireTheme.mintCore.opacity(0.1), radius: 6, x: 0, y:  4)
                        .disabled(isLoading)
                    
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
                        . shadow(color: EmpireTheme.mintCore.opacity(0.1), radius: 6, x: 0, y: 4)
                        .disabled(isLoading)
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showPassword.toggle()
                            }
                        } label: {
                            Image(systemName: showPassword ? "eye.slash. fill" : "eye.fill")
                                .foregroundColor(EmpireTheme.mintCore.opacity(0.7))
                                .padding(.trailing, 16)
                        }
                        .buttonStyle(. plain)
                        .disabled(isLoading)
                    }
                    
                    // ✅ Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                            .transition(.opacity)
                    }
                    
                    HStack {
                        Spacer()
                        Button("Forgot Password? ") {
                            showForgotPassword = true
                        }
                        .buttonStyle(.plain)
                        . foregroundColor(EmpireTheme.mintCore.opacity(0.85))
                        .font(.footnote)
                        .disabled(isLoading)
                    }
                }
                
                // ✅ UPDATED: Log In Button
                Button {
                    performLogin()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: . white))
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Logging in..." : "Log In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style:  .continuous)
                            .fill(EmpireTheme.mintCore)
                    )
                    . empireMintShadow(radius: 10, x: 0, y: 5, opacity: 0.6)
                    .foregroundColor(.white)
                }
                .disabled(isLoading || email.isEmpty || password.count < 6)
                .opacity((isLoading || email.isEmpty || password.count < 6) ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.2), value: email.isEmpty || password.count < 6)
                
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
                . padding(.vertical, 8)
                
                // Apple Sign-in placeholder button
                Button {
                    // no action yet
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "applelogo")
                            .font(.title2)
                        Text("Sign in with Apple")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(EmpireTheme.mintCore)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: . continuous)
                            .stroke(EmpireTheme.mintCore.opacity(0.7), lineWidth: 1.5)
                            .background(. ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: EmpireTheme.mintCore.opacity(0.15), radius: 6, x: 0, y: 3)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                
                Spacer(minLength: 10)
                
                // Footer HStack
                HStack(spacing: 4) {
                    Text("Don't have an account? ")
                        .foregroundColor(EmpireTheme.mintCore.opacity(0.7))
                        .font(.footnote)
                    Button("Sign Up") {
                        showSignUp = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(EmpireTheme.mintCore)
                    .disabled(isLoading)
                }
                .padding(.bottom, 10)
                
            }
            .padding(32)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(. ultraThinMaterial)
            )
            .empireMintGlassStroke(cornerRadius: 32, lineWidth: 1.5)
            .shadow(color: EmpireTheme.mintCore.opacity(0.3), radius: 20, x: 0, y:  10)
            .padding(. horizontal, 24)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(authViewModel)  // ✅ Pass authViewModel to SignUpView
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }
    
    // ✅ UPDATED: Backend login function with AuthViewModel
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
                    errorMessage = "An unexpected error occurred"
                    isLoading = false
                    
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private var animatedBackground: some View {
        EmpireTheme.mintDarkGradient(start: animateGradient ? .topLeading : .bottomTrailing,
                                 end: animateGradient ?  .bottomTrailing : .topLeading)
            .animation(.easeInOut(duration: 6).repeatForever(autoreverses:  true), value: animateGradient)
            .onAppear {
                animateGradient = true
            }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
            .preferredColorScheme(.dark)
    }
}
