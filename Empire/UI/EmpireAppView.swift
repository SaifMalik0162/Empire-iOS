import SwiftUI

struct EmpireAppView: View {
    var body: some View {
        ZStack {
            EmpireTabView() 
        }
        .edgesIgnoringSafeArea(.all)
    }
}
