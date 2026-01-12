import SwiftUI
import PhotosUI

struct VehicleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var car: Car
    var onSave: (Car) -> Void

    @State private var tempName: String
    @State private var tempDescription: String
    @State private var tempImageName: String
    @State private var tempHorsepower: Int
    @State private var tempStage: Int
    @State private var tempSpecs: [SpecItem]
    @State private var tempMods: [ModItem]

    init(car: Binding<Car>, onSave: @escaping (Car) -> Void) {
        self._car = car
        self.onSave = onSave
        _tempName = State(initialValue: car.wrappedValue.name)
        _tempDescription = State(initialValue: car.wrappedValue.description)
        _tempImageName = State(initialValue: car.wrappedValue.imageName)
        _tempHorsepower = State(initialValue: car.wrappedValue.horsepower)
        _tempStage = State(initialValue: car.wrappedValue.stage)
        _tempSpecs = State(initialValue: car.wrappedValue.specs)
        _tempMods = State(initialValue: car.wrappedValue.mods)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image with mint-glass style
                    ZStack {
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(Color("EmpireMint").opacity(0.25))
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color("EmpireMint").opacity(0.3), radius: 10, x: 0, y: 4)
                            .frame(height: 180)
                        VStack(spacing: 10) {
                            Image(tempImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 110)
                                .opacity(0.9)
                            Text("Tap to change image (placeholder)")
                                .font(.caption)
                                .foregroundColor(Color("EmpireMint").opacity(0.7))
                        }
                        .padding()
                    }

                    // Basic fields with mint-glass style
                    Group {
                        GlassField(title: "Name", text: $tempName)
                        GlassField(title: "Description", text: $tempDescription)
                        GlassStepper(title: "Horsepower", value: $tempHorsepower, range: 0...2000, suffix: " HP")
                        GlassStepper(title: "Stage", value: $tempStage, range: 0...5)
                    }

                    // Specs section with dynamic editing
                    GlassSection(title: "Specs") {
                        ForEach($tempSpecs) { $spec in
                            HStack(spacing: 12) {
                                GlassTextField(placeholder: "Key", text: $spec.key)
                                GlassTextField(placeholder: "Value", text: $spec.value)
                                Button(role: .destructive) {
                                    tempSpecs.removeAll { $0.id == spec.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                            }
                        }
                        Button {
                            tempSpecs.append(SpecItem(key: "", value: ""))
                        } label: {
                            Label("Add Spec", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("EmpireMint"))
                        .padding(.top, 6)
                    }

                    // Mods section with dynamic editing
                    GlassSection(title: "Mods") {
                        ForEach($tempMods) { $mod in
                            HStack(spacing: 12) {
                                GlassTextField(placeholder: "Title", text: $mod.title)
                                GlassTextField(placeholder: "Notes", text: $mod.notes)
                                Button(role: .destructive) {
                                    tempMods.removeAll { $0.id == mod.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                            }
                        }
                        Button {
                            tempMods.append(ModItem(title: ""))
                        } label: {
                            Label("Add Mod", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("EmpireMint"))
                        .padding(.top, 6)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }

    private func saveAndDismiss() {
        var updated = car
        updated.name = tempName
        updated.description = tempDescription
        updated.imageName = tempImageName
        updated.horsepower = tempHorsepower
        updated.stage = tempStage
        updated.specs = tempSpecs
        updated.mods = tempMods
        onSave(updated)
        dismiss()
    }
}

// MARK: - Subviews styled like mint-glass (similar to ProfileView)

private struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(Color("EmpireMint"))
            VStack(spacing: 12) {
                content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color("EmpireMint").opacity(0.15))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.07)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
}

private struct GlassField: View {
    let title: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundColor(Color("EmpireMint").opacity(0.9))
            GlassTextField(placeholder: title, text: $text)
        }
    }
}

private struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color("EmpireMint").opacity(0.15))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .foregroundColor(Color("EmpireMint").opacity(0.9))
    }
}

private struct GlassStepper: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var suffix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(Color("EmpireMint").opacity(0.9))
                Spacer()
                Text("\(value)\(suffix)")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color("EmpireMint"))
            }
            Stepper(value: $value, in: range) {
                EmptyView()
            }
            .labelsHidden()
        }
    }
}
