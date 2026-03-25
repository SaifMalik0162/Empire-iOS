import SwiftUI

struct ManageGarageSheet: View {
    @ObservedObject var vehiclesVM: UserVehiclesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var confirmDeleteIndex: Int? = nil
    @State private var editingIndex: Int? = nil
    @State private var showEditor: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // App background style
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        header

                        if vehiclesVM.vehicles.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(vehiclesVM.vehicles.enumerated()), id: \.offset) { pair in
                                    let item = IndexedCar(index: pair.offset, car: pair.element)
                                    VehicleRowCard(item: item) {
                                        editingIndex = item.index
                                        showEditor = true
                                    } onDelete: {
                                        confirmDeleteIndex = item.index
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Manage Garage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let idx = vehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                            editingIndex = idx
                            showEditor = true
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }
        .confirmationDialog("Delete this car?", isPresented: Binding(get: { confirmDeleteIndex != nil }, set: { newVal in if !newVal { confirmDeleteIndex = nil } })) {
            Button("Delete", role: .destructive) {
                if let i = confirmDeleteIndex {
                    vehiclesVM.removeVehicles(at: IndexSet(integer: i))
                }
                confirmDeleteIndex = nil
            }
            Button("Cancel", role: .cancel) { confirmDeleteIndex = nil }
        }
        .sheet(isPresented: $showEditor) {
            if let idx = editingIndex, vehiclesVM.vehicles.indices.contains(idx) {
                VehicleEditorView(car: $vehiclesVM.vehicles[idx]) { updated in
                    vehiclesVM.updateVehicle(at: idx, with: updated)
                }
                .preferredColorScheme(.dark)
            } else if let first = vehiclesVM.vehicles.indices.first {
                VehicleEditorView(car: $vehiclesVM.vehicles[first]) { updated in
                    vehiclesVM.updateVehicle(at: first, with: updated)
                }
                .preferredColorScheme(.dark)
                .onAppear { editingIndex = first }
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(Color("EmpireMint"))
                    Text("Loading editor...")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
                .padding()
                .preferredColorScheme(.dark)
                .task {
                    // Retry shortly in case a placeholder was just added
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    if let first = vehiclesVM.vehicles.indices.first {
                        await MainActor.run {
                            editingIndex = first
                            showEditor = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header & Search
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Your vehicles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("EmpireMint"))
                Spacer()
                if !vehiclesVM.vehicles.isEmpty {
                    Text("\(vehiclesVM.vehicles.count) total")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        )
                }
            }
            // Helper hint row
            HStack {
                Image(systemName: "hand.point.up.left.fill").font(.caption.weight(.bold)).foregroundStyle(Color("EmpireMint"))
                Text("Long-press a vehicle for actions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("No vehicles yet")
                .foregroundStyle(.white)
                .font(.subheadline.weight(.semibold))
            Text("Start building your garage by adding your first car.")
                .foregroundStyle(.white.opacity(0.7))
                .font(.caption)
            Button {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
                if let idx = vehiclesVM.addPlaceholderVehicleAndReturnIndex() {
                    editingIndex = idx
                    showEditor = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add your first vehicle")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("EmpireMint"))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Color("EmpireMint").opacity(0.22), radius: 14, y: 6)
    }
}

// MARK: - Helper Types
private struct IndexedCar {
    let index: Int
    let car: Car
}

// MARK: - Vehicle Row Card
private struct VehicleRowCard: View {
    let item: IndexedCar
    var onTap: () -> Void
    var onDelete: () -> Void

    @State private var pressed: Bool = false

    private var subtitle: String {
        // Prefer make + model if present; else fall back to existing description
        let make = (item.car.make ?? "").trimmingCharacters(in: .whitespaces)
        let model = (item.car.model ?? "").trimmingCharacters(in: .whitespaces)
        let combined = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        if !combined.isEmpty { return combined }
        return item.car.description
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let data = loadPhotoDataFromDisk(fileName: item.car.photoFileName), let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(item.car.imageName)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 72, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.car.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            HStack(spacing: 4) {
                // Small stat capsules inline
                if item.car.isJailbreak {
                    StatCapsule(label: "Jailbreak", value: "", tint: .purple)
                } else if item.car.stage == 0 {
                    StatCapsule(label: "Stock", value: "", tint: .gray)
                } else {
                    StatCapsule(label: "Stage", value: "\(item.car.stage)", tint: stageTint(for: item.car.stage))
                }
                StatCapsule(label: "WHP", value: "\(item.car.horsepower)", tint: .cyan)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Color("EmpireMint").opacity(0.18), radius: 10, x: 0, y: 6)
        .scaleEffect(pressed ? 0.98 : 1)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) { pressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { pressed = false } }
        )
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                onTap()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .onTapGesture { onTap() }
    }
}


// MARK: - Local helpers mirrored from CarsView
private func loadPhotoDataFromDisk(fileName: String?) -> Data? {
    guard let fileName else { return nil }
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let url = dir.appendingPathComponent(fileName)
    return try? Data(contentsOf: url)
}

private func stageTint(for stage: Int) -> Color {
    switch stage {
    case 1: return Color("EmpireMint")
    case 2: return .yellow
    case 3: return .red
    default: return .gray
    }
}

private struct StatCapsule: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(tint.opacity(0.9))
            Text(value)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.6), lineWidth: 1)
        )
    }
}
