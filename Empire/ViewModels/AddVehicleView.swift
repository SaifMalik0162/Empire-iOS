import SwiftUI

struct AddVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    let vm: UserVehiclesViewModel

    var body: some View {
        NavigationView {
            Form {
                Button("Close") {
                    dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle("Add Vehicle")
        }
    }
}
