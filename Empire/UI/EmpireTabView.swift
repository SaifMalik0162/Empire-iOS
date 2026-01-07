import SwiftUI

struct EmpireTabView: View {
    @State private var selectedTab: EmpireTab = .home
    @State private var searchText: String = ""

    @State private var meets: [Meet] = [
        Meet(title: "Empire Meet 1", city: "Toronto", date: Date()),
        Meet(title: "Empire Meet 2", city: "Montreal", date: Date().addingTimeInterval(86400)),
        Meet(title: "Empire Meet 3", city: "Vancouver", date: Date().addingTimeInterval(86400*2))
    ]

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Image(systemName: EmpireTab.home.icon) }
                .tag(EmpireTab.home)
            
            MeetsView(meets: meets)
                .tabItem { Image(systemName: EmpireTab.meets.icon) }
                .tag(EmpireTab.meets)
            
            CarsView()
                .tabItem { Image(systemName: EmpireTab.cars.icon) }
                .tag(EmpireTab.cars)
            
            MerchView()
                .tabItem { Image(systemName: EmpireTab.merch.icon) }
                .tag(EmpireTab.merch)
            
            ProfileView()
                .tabItem { Image(systemName: EmpireTab.profile.icon) }
                .tag(EmpireTab.profile)
        }
        .labelStyle(.iconOnly)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .tint(Color("EmpireMint"))
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .searchable(text: $searchText)
    }
}
