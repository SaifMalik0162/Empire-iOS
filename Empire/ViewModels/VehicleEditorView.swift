import SwiftUI
import PhotosUI
import UIKit

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
    @State private var tempIsJailbreak: Bool
    @State private var tempVehicleClass: VehicleClass?

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var tempPhotoData: Data? = nil

    private let userStorageKey: String

    @State private var selectedModIDs: Set<UUID> = []
    @State private var selectedPresetMods: Set<String> = []
    @State private var showStageSuggestion: Bool = true

    init(car: Binding<Car>, onSave: @escaping (Car) -> Void) {
        self._car = car
        self.onSave = onSave

        // Best-effort per-user key (falls back to "default").
        let currentUserId = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
        self.userStorageKey = currentUserId

        // If a saved version exists for this car id, prefer it for initial editor state.
        let baseCar = Self.loadSavedCar(for: car.wrappedValue.id, userKey: currentUserId) ?? car.wrappedValue

        _tempName = State(initialValue: baseCar.name)
        _tempDescription = State(initialValue: baseCar.description)
        _tempImageName = State(initialValue: baseCar.imageName)
        _tempHorsepower = State(initialValue: baseCar.horsepower)
        _tempStage = State(initialValue: baseCar.stage)
        _tempSpecs = State(initialValue: baseCar.specs.isEmpty ? VehicleEditorView.defaultSpecs() : baseCar.specs)
        _tempMods = State(initialValue: baseCar.mods)
        _tempIsJailbreak = State(initialValue: baseCar.isJailbreak)
        _tempVehicleClass = State(initialValue: baseCar.vehicleClass)

        // Load any previously saved photo for this car id.
        _tempPhotoData = State(initialValue: Self.loadSavedPhotoData(for: car.wrappedValue.id, userKey: currentUserId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
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
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                VStack(spacing: 10) {
                                    if let data = tempPhotoData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 110)
                                            .opacity(0.95)
                                    } else {
                                        Image(tempImageName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 110)
                                            .opacity(0.9)
                                    }
                                    Text("Tap to change image")
                                        .font(.caption)
                                        .foregroundColor(Color("EmpireMint").opacity(0.7))
                                }
                                .padding()
                            }
                            .buttonStyle(.plain)
                        }

                        // Basic fields with mint-glass style
                        Group {
                            GlassField(title: "Name", text: $tempName)
                            StageSelector(stage: $tempStage, isJailbreak: $tempIsJailbreak)
                        }

                        // Specs section with dynamic editing
                        GlassSection(title: "Specs") {
                            GlassNumberField(title: "Horsepower", value: $tempHorsepower, suffix: " HP")
                            ForEach(tempSpecs, id: \.id) { spec in
                                HStack(spacing: 8) {
                                    // Key pill
                                    Text(spec.key.isEmpty ? "Engine" : spec.key)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.white.opacity(0.06)))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                        .foregroundStyle(.white)
                                        .contentShape(Capsule())
                                        .onTapGesture {
                                            // No-op here; focus will be on value field
                                        }

                                    // Compact inline value field
                                    GlassTextField(placeholder: "Value", text: Binding(get: {
                                        if let idx = tempSpecs.firstIndex(where: { $0.id == spec.id }) { return tempSpecs[idx].value } else { return "" }
                                    }, set: { newVal in
                                        if let idx = tempSpecs.firstIndex(where: { $0.id == spec.id }) { tempSpecs[idx].value = newVal }
                                    }))
                                }
                            }
                        }

                        // Mods section with dynamic editing
                        GlassSection(title: "Mods") {
                            QuickAddModsRow(selectedPresets: $selectedPresetMods)
                            let modGridColumns: [GridItem] = [GridItem(.adaptive(minimum: 140), spacing: 8)]
                            LazyVGrid(columns: modGridColumns, spacing: 8) {
                                ForEach(Array(tempMods.enumerated()), id: \.element.id) { index, item in
                                    let id = item.id
                                    ModPillView(
                                        title: item.title.isEmpty ? "Untitled Mod" : item.title,
                                        isMajor: item.isMajor,
                                        isSelected: selectedModIDs.contains(id),
                                        onToggleSelect: {
                                            if selectedModIDs.contains(id) {
                                                selectedModIDs.remove(id)
                                            } else {
                                                selectedModIDs.insert(id)
                                            }
                                        },
                                        onDelete: {
                                            if let removeIndex = tempMods.firstIndex(where: { $0.id == id }) {
                                                tempMods.remove(at: removeIndex)
                                            }
                                            selectedModIDs.remove(id)
                                        }
                                    )
                                }
                            }
                        }

                        GlassSection(title: "Vehicle Class") {
                            Picker("Class", selection: Binding(get: { tempVehicleClass ?? VehicleClass.a_FWD_Tuner }, set: { tempVehicleClass = $0 })) {
                                ForEach(VehicleClass.allCases) { cls in
                                    Text(labelForClass(cls))
                                        .tag(cls)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color("EmpireMint"))
                        }
                    }
                    .padding(20)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                self.tempPhotoData = data
                            }
                        }
                    }
                }
                .overlay(
                    Group {
                        if showStageSuggestion {
                            // Count selected presets + selected mod pills
                            let selectedPresetCount = selectedPresetMods.count
                            let selectedModCount = tempMods.filter { selectedModIDs.contains($0.id) }.count
                            let totalSelectedCount = selectedPresetCount + selectedModCount

                            // Detect if any selected item (preset or pill) is a tune
                            let hasTuneFromPresets = selectedPresetMods.contains { $0.localizedCaseInsensitiveContains("tune") }
                            let hasTuneFromSelectedMods = tempMods.contains { mod in
                                selectedModIDs.contains(mod.id) && mod.title.localizedCaseInsensitiveContains("tune")
                            }
                            let hasTuneAny = hasTuneFromPresets || hasTuneFromSelectedMods

                            StageSuggestionBanner(majorModsCount: totalSelectedCount, hasTune: hasTuneAny) {
                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.impactOccurred()
                                // Ensure we're not in Jailbreak and select Stage 2 explicitly
                                tempIsJailbreak = false
                                tempStage = 2
                                withAnimation(.easeOut(duration: 0.25)) { showStageSuggestion = false }
                            }
                        }
                    }
                )
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
        updated.isJailbreak = tempIsJailbreak
        updated.vehicleClass = tempVehicleClass
        // Persist per-user so edits survive relaunch.
        Self.saveCar(updated, userKey: userStorageKey)
        if let data = tempPhotoData {
            Self.savePhotoData(data, for: updated.id, userKey: userStorageKey)
        }
        onSave(updated)
        dismiss()
    }

    private static func defaultSpecs() -> [SpecItem] {
        return [
            SpecItem(key: "Engine", value: ""),
            SpecItem(key: "Drivetrain", value: ""),
            SpecItem(key: "Transmission", value: ""),
            SpecItem(key: "Tires", value: ""),
            SpecItem(key: "Weight", value: "")
        ]
    }

    private func bindingForMod(id: UUID) -> Binding<ModItem>? {
        guard let idx = tempMods.firstIndex(where: { $0.id == id }) else { return nil }
        return $tempMods[idx]
    }

    // MARK: - Persistence (UserDefaults)

    private static func carStorageKey(for id: UUID, userKey: String) -> String {
        "saved_car_\(userKey)_\(id.uuidString)"
    }

    private static func carPhotoStorageKey(for id: UUID, userKey: String) -> String {
        "saved_car_photo_\(userKey)_\(id.uuidString)"
    }

    private static func saveCar(_ car: Car, userKey: String) {
        do {
            let data = try JSONEncoder().encode(car)
            UserDefaults.standard.set(data, forKey: carStorageKey(for: car.id, userKey: userKey))
        } catch {
            // Intentionally ignore save failures in UI layer.
        }
    }

    private static func loadSavedCar(for id: UUID, userKey: String) -> Car? {
        guard let data = UserDefaults.standard.data(forKey: carStorageKey(for: id, userKey: userKey)) else { return nil }
        return try? JSONDecoder().decode(Car.self, from: data)
    }

    private static func savePhotoData(_ data: Data, for id: UUID, userKey: String) {
        UserDefaults.standard.set(data, forKey: carPhotoStorageKey(for: id, userKey: userKey))
    }

    private static func loadSavedPhotoData(for id: UUID, userKey: String) -> Data? {
        UserDefaults.standard.data(forKey: carPhotoStorageKey(for: id, userKey: userKey))
    }

    private func labelForClass(_ cls: VehicleClass) -> String {
        switch cls {
        case .a_FWD_Tuner: return "A - FWD Tuner"
        case .performance4Cyl: return "B - Performance 4-Cylinder"
        case .sixCylinderStreet: return "C - 6-Cylinder Street"
        case .highPerformance: return "S - High-Performance Sports"
        case .m_AmericanMuscle: return "M - American Muscle"
        case .importV8: return "I - Import V8 Performance"
        case .supercar: return "X - Supercars & Hypercars"
        case .electricHybrid: return "E - Electric & Hybrid"
        case .trackOnly: return "T - Track-Only"
        }
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

private struct GlassNumberField: View {
    let title: String
    @Binding var value: Int
    var suffix: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote).foregroundColor(.white.opacity(0.8))
            HStack {
                TextField(title, value: $value, formatter: NumberFormatter())
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                    .foregroundColor(.white)
                if !suffix.isEmpty { Text(suffix).foregroundColor(.white.opacity(0.8)).font(.footnote) }
            }
        }
    }
}

private struct QuickAdjustRow: View {
    let adjustments: [Int]
    var onAdjust: (Int) -> Void
    var body: some View {
        HStack(spacing: 10) {
            ForEach(adjustments, id: \.self) { delta in
                Button(action: { onAdjust(delta) }) {
                    Text("+\(delta)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct StageSelector: View {
    @Binding var stage: Int
    @Binding var isJailbreak: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stage").font(.footnote).foregroundColor(.white.opacity(0.8))
            HStack(spacing: 8) {
                ForEach(0...3, id: \.self) { s in
                    Button(action: { isJailbreak = false; stage = s }) {
                        Text(s == 0 ? "Stock" : "Stage \(s)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(.ultraThinMaterial))
                            .overlay(
                                Capsule().stroke(
                                    (stage == s && !isJailbreak) ? stageTint(for: s).opacity(0.9) : Color.white.opacity(0.25),
                                    lineWidth: 1
                                )
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: { isJailbreak = true }) {
                    Text("Jailbreak")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(isJailbreak ? Color.purple.opacity(0.9) : Color.white.opacity(0.25), lineWidth: 1))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct QuickAddModsRow: View {
    @Binding var selectedPresets: Set<String>
    private let presets: [String] = ["Tune", "Intake", "Headers", "Exhaust", "Forced Induction", "Motor Swap", "Drivetrain Swap", "Transmission Upgrades", "Built Motor"]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { (p: String) in
                    let isSelected = selectedPresets.contains(p)
                    Button(action: {
                        if isSelected { selectedPresets.remove(p) } else { selectedPresets.insert(p) }
                    }) {
                        Text(p)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(isSelected ? Color.green.opacity(0.22) : Color.white.opacity(0.06))
                            )
                            .overlay(
                                Capsule().stroke(
                                    isSelected ? Color.green.opacity(0.9) : Color.white.opacity(0.3),
                                    lineWidth: 1
                                )
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct StageSuggestionBanner: View {
    let majorModsCount: Int
    let hasTune: Bool
    var onApply: () -> Void
    @State private var animatePhase: CGFloat = 0

    var body: some View {
        if majorModsCount >= 3 && hasTune {
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color("EmpireMint"))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("3+ major mods incl. Tune detected.")
                            .font(.footnote)
                            .foregroundColor(.white)
                        Text("Suggest Stage 2.")
                            .font(.footnote)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button("Apply") { onApply() }
                        .font(.footnote.weight(.semibold))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AnimatedMintGradient(phase: animatePhase), lineWidth: 2)
                )
                .padding(.horizontal, 24)
                .shadow(color: Color("EmpireMint").opacity(0.35), radius: 16, x: 0, y: 8)
                .onAppear {
                    withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                        animatePhase = 1
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct AnimatedMintGradient: ShapeStyle {
    var phase: CGFloat
    func _apply(to shape: inout _ShapeStyle_Shape) {
        // Compute wrapped locations around phase in [0,1)
        let loc1 = fmod(phase - 0.2 + 1, 1)
        let loc2 = fmod(phase + 0.0 + 1, 1)
        let loc3 = fmod(phase + 0.2 + 1, 1)

        // Pair with colors and sort by location to satisfy SwiftUI's requirement
        let stops = [
            (location: loc1, color: Color("EmpireMint").opacity(0.2)),
            (location: loc2, color: Color("EmpireMint").opacity(0.9)),
            (location: loc3, color: Color("EmpireMint").opacity(0.2))
        ].sorted { $0.location < $1.location }

        let gradient = LinearGradient(
            gradient: Gradient(stops: stops.map { .init(color: $0.color, location: $0.location) }),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        gradient._apply(to: &shape)
    }
}

private struct ModRow: View {
    let id: UUID
    @Binding var title: String
    @Binding var notes: String
    @Binding var isMajor: Bool
    var onDelete: () -> Void

    init(id: UUID,
         titleBinding: Binding<String>,
         notesBinding: Binding<String>,
         isMajorBinding: Binding<Bool>,
         onDelete: @escaping () -> Void) {
        self.id = id
        self._title = titleBinding
        self._notes = notesBinding
        self._isMajor = isMajorBinding
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 12) {
            GlassTextField(placeholder: "Title", text: $title)
            GlassTextField(placeholder: "Notes", text: $notes)
            Toggle("Major", isOn: $isMajor)
                .toggleStyle(.switch)
                .labelsHidden()
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
    }
}

private struct ModRowBinding: View {
    @Binding var mod: ModItem
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            GlassTextField(placeholder: "Title", text: $mod.title)
            GlassTextField(placeholder: "Notes", text: $mod.notes)
            Toggle("Major", isOn: $mod.isMajor)
                .toggleStyle(.switch)
                .labelsHidden()
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
    }
}

private struct ModPillView: View {
    let title: String
    let isMajor: Bool
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if isMajor {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
            Spacer(minLength: 0)
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(isSelected ? Color.green.opacity(0.22) : Color.white.opacity(0.06))
        )
        .overlay(
            Group {
                if isSelected {
                    Capsule().stroke(Color.green.opacity(0.9), lineWidth: 1)
                } else {
                    Capsule().stroke(
                        LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
                }
            }
        )
        .contentShape(Capsule())
        .simultaneousGesture(
            TapGesture().onEnded {
                onToggleSelect()
            }
        )
    }
}

private func stageTint(for stage: Int) -> Color {
    switch stage {
    case 0: return .gray
    case 1: return Color("EmpireMint")
    case 2: return .yellow
    case 3: return .red
    default: return .gray
    }
}
