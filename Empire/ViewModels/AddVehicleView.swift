import SwiftUI

struct EmpireAddVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: UserVehiclesViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Add Vehicle")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)

                Button {
                    vm.addPlaceholderVehicle()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Placeholder Vehicle")
                    }
                    .font(.headline)
                    .foregroundColor(Color("EmpireMint"))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)

                Button("Close") { dismiss() }
                    .foregroundColor(.white)
                    .padding(.top, 8)

                Spacer()
            }
            .padding()
            .background(
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Add Vehicle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    EmpireAddVehicleView(vm: UserVehiclesViewModel())
        .preferredColorScheme(.dark)
}
