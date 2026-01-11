import SwiftUI

struct EmpireTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var cart: Cart  // ✅ Use existing Cart
    @State private var selectedTab: EmpireTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .meets:
                    MeetsView()
                        .environmentObject(authViewModel)
                case .cars:
                    CarsView()
                        .environmentObject(authViewModel)
                case .merch:
                    MerchView()
                        .environmentObject(authViewModel)
                        .environmentObject(cart)  // ✅ Pass existing Cart
                case .profile:
                    ProfileView()
                        .environmentObject(authViewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LiquidGlassTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(. bottom, 10)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    EmpireTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(Cart())  // ✅ Use existing Cart
        . preferredColorScheme(.dark)
}
