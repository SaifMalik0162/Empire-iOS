import SwiftUI
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var appleNonce = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let appleSignInController = AppleSignInController()

    @EnvironmentObject var authViewModel: AuthViewModel

    private var isLoginDisabled: Bool {
        isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 6
    }

    var body: some View {
        AuthScreen {
            AuthPanel {
                VStack(spacing: 16) {
                    AuthHeader(
                        title: "Welcome back to Empire",
                        subtitle: "Sign in to continue."
                    )

                    VStack(spacing: 14) {
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
                            contentType: .password,
                            isSecure: true,
                            revealSecureText: showPassword,
                            onToggleSecure: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showPassword.toggle()
                                }
                            }
                        )

                        HStack {
                            Spacer()

                            Button("Forgot password?") {
                                showForgotPassword = true
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(EmpireTheme.mintCore)
                        }

                        if let errorMessage {
                            AuthMessage(text: errorMessage, tone: .error)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    AuthPrimaryButton(
                        title: isLoading ? "Signing in..." : "Log In",
                        isLoading: isLoading,
                        isDisabled: isLoginDisabled
                    ) {
                        performLogin()
                    }

                    AuthDivider(label: "Or Continue With")

                    VStack(spacing: 12) {
                        AuthSocialButton(title: "Continue with Google") {
                            GoogleBrandMark()
                        } action: {
                            performGoogleLogin()
                        }
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.55 : 1)

                        AuthSocialButton(title: "Continue with Apple") {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        } action: {
                            beginAppleSignIn()
                        }
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.55 : 1)
                    }

                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundStyle(AuthPalette.textSecondary)
                        Button("Create one") {
                            showSignUp = true
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(EmpireTheme.mintCore)
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
            }
        }
        .onAppear {
            appleSignInController.completion = handleAppleSignIn
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authViewModel)
        }
    }

    private func performLogin() {
        isLoading = true
        errorMessage = nil

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            do {
                try await authViewModel.login(email: email, password: password)

                await MainActor.run {
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            } catch {
                await MainActor.run {
                    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = message.isEmpty ? "An unexpected error occurred." : message
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func performGoogleLogin() {
        isLoading = true
        errorMessage = nil

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            do {
                guard let presentingViewController = activePresentationRoot else {
                    throw AuthUserFacingError.generic("Google sign-in is unavailable right now. Please try again.")
                }

                let googleNonce = randomNonceString()
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: presentingViewController,
                    hint: nil,
                    additionalScopes: nil,
                    nonce: sha256(googleNonce)
                )

                guard let idToken = result.user.idToken?.tokenString else {
                    throw AuthUserFacingError.generic("Google sign-in did not return an identity token.")
                }

                try await authViewModel.loginWithGoogle(
                    idToken: idToken,
                    accessToken: result.user.accessToken.tokenString,
                    nonce: googleNonce
                )

                await MainActor.run {
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch let error as NSError
                where error.domain == kGIDSignInErrorDomain &&
                    error.code == -5 {
                await MainActor.run {
                    isLoading = false
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            } catch {
                await MainActor.run {
                    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = message.isEmpty ? "Google sign-in failed." : message
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func beginAppleSignIn() {
        errorMessage = nil
        appleNonce = randomNonceString()
        appleSignInController.startSignIn(hashedNonce: sha256(appleNonce))
    }

    private var activePresentationRoot: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .topMostViewController
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
                    errorMessage = message.isEmpty ? "Apple sign-in failed." : message
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

private final class AppleSignInController: NSObject {
    var completion: ((Result<ASAuthorization, Error>) -> Void)?

    func startSignIn(hashedNonce: String) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

extension AppleSignInController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return window
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return UIWindow(windowScene: windowScene)
        }

        fatalError("No active window scene available for Apple sign-in presentation.")
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion?(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(.failure(error))
    }
}

private extension UIViewController {
    var topMostViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostViewController
        }

        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.topMostViewController
        }

        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.topMostViewController
        }

        return self
    }
}

private struct GoogleBrandMark: View {
    var body: some View {
        Group {
            if let image = googleLogoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("G")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private var googleLogoImage: UIImage? {
        let bundleNames = ["GoogleSignIn_GoogleSignIn", "GoogleSignIn"]
        let candidateBundles = bundleNames.compactMap { bundleName -> Bundle? in
            if let mainBundlePath = Bundle.main.path(forResource: bundleName, ofType: "bundle") {
                return Bundle(path: mainBundlePath)
            }

            let frameworkBundle = Bundle(for: GIDSignIn.self)
            if let frameworkBundlePath = frameworkBundle.path(forResource: bundleName, ofType: "bundle") {
                return Bundle(path: frameworkBundlePath)
            }

            return nil
        }

        for bundle in candidateBundles {
            if let image = UIImage(named: "google", in: bundle, compatibleWith: nil) {
                return image
            }
        }

        return nil
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .preferredColorScheme(.dark)
    }
}
