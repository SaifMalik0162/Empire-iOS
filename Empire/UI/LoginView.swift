import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showSignUp = false
    
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            animatedBackground
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                
                // App Icon with circular glass backdrop
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 96, height: 96)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: Color.accentColor.opacity(0.15), radius: 10, x: 0, y: 4)
                    Image("AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                }
                .padding(.bottom, 12)
                
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1.25)
                                )
                        )
                        .shadow(color: Color.accentColor.opacity(0.1), radius: 6, x: 0, y: 4)
                    
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1.25)
                                )
                        )
                        .shadow(color: Color.accentColor.opacity(0.1), radius: 6, x: 0, y: 4)
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showPassword.toggle()
                            }
                        } label: {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(Color.accentColor.opacity(0.7))
                                .padding(.trailing, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Log In Button
                Button {
                    // No action yet
                } label: {
                    Text("Log In")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.accentColor)
                                .shadow(color: Color.accentColor.opacity(0.6), radius: 10, x: 0, y: 5)
                        )
                        .foregroundColor(.white)
                }
                .disabled(email.isEmpty || password.count < 6)
                .opacity(email.isEmpty || password.count < 6 ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.2), value: email.isEmpty || password.count < 6)
                
                // Divider with "or"
                HStack {
                    Divider()
                        .background(Color.accentColor.opacity(0.4))
                    Text("or")
                        .foregroundColor(Color.accentColor.opacity(0.6))
                        .font(.footnote)
                        .fontWeight(.medium)
                    Divider()
                        .background(Color.accentColor.opacity(0.4))
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
                    .foregroundColor(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.accentColor.opacity(0.15), radius: 6, x: 0, y: 3)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer(minLength: 10)
                
                // Footer HStack
                HStack(spacing: 4) {
                    Text("Don’t have an account?")
                        .foregroundColor(Color.accentColor.opacity(0.7))
                        .font(.footnote)
                    Button("Sign Up") {
                        showSignUp = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.accentColor)
                }
                .padding(.bottom, 10)
                
            }
            .padding(32)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.25), lineWidth: 1.5)
                    )
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
    }
    
    private var animatedBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.2, green: 0.5, blue: 0.9),
                Color(red: 0.1, green: 0.3, blue: 0.7),
                Color(red: 0.0, green: 0.4, blue: 0.9),
                Color(red: 0.2, green: 0.5, blue: 0.9)
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
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
