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
        ZStack {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .meets:
                    MeetsView(meets: meets)
                case .cars:
                    CarsView()
                case .merch:
                    MerchView()
                case .profile:
                    ProfileView()
                }
            }
            .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                LiquidGlassTabBar(selectedTab: $selectedTab)
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .searchable(text: $searchText)
    }
}
