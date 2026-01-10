import SwiftUI

@main
struct EmpireApp: App {
    @StateObject private var cart = Cart()
    
    var body: some Scene {
        WindowGroup {
            LoginView()
                .environmentObject(cart)
                .preferredColorScheme(.dark)
        }
    }
}
