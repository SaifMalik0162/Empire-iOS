import SwiftUI

@main
struct EmpireApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var cart = Cart()  // ✅ Use existing Cart
    
    var body:  some Scene {
        WindowGroup {
            if authViewModel.isLoading {
                EmpireSplashView()
                    .preferredColorScheme(.dark)
            } else if authViewModel.isAuthenticated {
                EmpireTabView()
                    .preferredColorScheme(.dark)
                    .environmentObject(authViewModel)
                    .environmentObject(cart)  // ✅ Pass existing Cart
            } else {
                LoginView()
                    .preferredColorScheme(.dark)
                    .environmentObject(authViewModel)
            }
        }
    }
}
