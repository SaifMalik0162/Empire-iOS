import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var isSending: Bool = false
    @State private var showValidation: Bool = false
    
    @State private var animateGradient = false
    
    private var animatedGradient: LinearGradient {
        EmpireTheme.mintDarkGradient(start: animateGradient ? .topLeading : .bottomTrailing,
                                     end: animateGradient ? .bottomTrailing : .topLeading)
    }
    
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
                EmpireLogoView(size: 150, style: .tinted(EmpireTheme.mintCore), shimmer: true, parallaxAmount: 0)
                
                VStack(spacing: 8) {
                    Text("Reset your password")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    
                    Text("Enter your email and we'll send you a reset link.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                }
                
                VStack(spacing: 6) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .empireMintGlassStroke(cornerRadius: 16, lineWidth: 1.25)
                        .shadow(color: EmpireTheme.mintCore.opacity(0.1), radius: 6, x: 0, y: 4)
                    
                    if showValidation && email.isEmpty {
                        Text("Please enter your email.")
                            .font(.footnote)
                            .foregroundColor(.red.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                
                Button {
                    showValidation = true
                    guard !email.isEmpty else { return }
                    isSending = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isSending = false
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isSending ? "Sending..." : "Send Reset Link")
                            .bold()
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
                    .empireMintShadow(radius: 10, x: 0, y: 5, opacity: 0.6)
                }
                .disabled(isSending)
                
                Button {
                    dismiss()
                } label: {
                    Text("Back to Login")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.vertical, 6)
                }
            }
            .padding(30)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .empireMintGlassStroke(cornerRadius: 32, lineWidth: 1.5)
            .shadow(color: EmpireTheme.mintCore.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                    }
                }
                Spacer()
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
        }
    }
}

#Preview {
    ForgotPasswordView()
        .preferredColorScheme(.dark)
}

