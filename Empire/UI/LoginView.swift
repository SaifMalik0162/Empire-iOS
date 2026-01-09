import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showMainApp: Bool = false
    
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
                }
                
                // Log In Button
                Button {
                    showMainApp = true
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
#if DEBUG
                .disabled(false)
                .opacity(1)
#else
                .disabled(email.isEmpty || password.count < 6)
                .opacity(email.isEmpty || password.count < 6 ? 0.5 : 1)
#endif
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
                .padding(.vertical, 8)
                
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
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(EmpireTheme.mintCore.opacity(0.7), lineWidth: 1.5)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: EmpireTheme.mintCore.opacity(0.15), radius: 6, x: 0, y: 3)
                    )
                }
                .buttonStyle(.plain)
                
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
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .fullScreenCover(isPresented: $showMainApp) {
            EmpireTabView()
                .preferredColorScheme(.dark)
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
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .preferredColorScheme(.dark)
    }
}

