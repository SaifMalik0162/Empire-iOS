import SwiftUI
import PhotosUI
import UIKit
import SwiftData

// MARK: - Glass Card & Shimmer Components

private struct EditorGlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color("EmpireMint").opacity(0.10))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color("EmpireMint").opacity(0.2), radius: 10, x: 0, y: 6)
    }
}

// MARK: - ImageStore
private enum ImageStore {
    static func save(_ data: Data, fileName: String) throws -> URL {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "ImageStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Documents directory not found"])
        }
        let fileURL = documentsURL.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    static func load(_ fileName: String) -> Data? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsURL.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }
}

struct VehicleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var car: Car
    var onSave: (Car) -> Void

    private enum Step {
        case details
        case modsSpecs
        case stage
    }
    @State private var step: Step = .details

    @State private var tempName: String
    @State private var tempDescription: String
    @State private var tempMake: String
    @State private var tempModel: String
    @State private var tempImageName: String
    @State private var tempHorsepower: Int
    @State private var tempStage: Int
    @State private var tempSpecs: [SpecItem]
    @State private var tempMods: [ModItem]
    @State private var tempVehicleClass: VehicleClass?

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var tempPhotoData: Data? = nil

    private let userStorageKey: String

    @State private var selectedModIDs: Set<UUID> = []
    @State private var selectedPresetMods: Set<String> = []

    @State private var stageCarouselSelection: Int = 0
    @State private var showStageWarning: Bool = false
    @State private var attemptedStageSelection: Int? = nil

    private static let presetSet: Set<String> = [
        "Tune", "Intake", "Headers", "Exhaust", "Forced Induction",
        "Motor Swap", "Drivetrain Swap", "Transmission Upgrades", "Built Motor"
    ]

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
        _tempMake = State(initialValue: baseCar.make ?? "")
        _tempModel = State(initialValue: baseCar.model ?? "")
        _tempImageName = State(initialValue: baseCar.imageName)
        _tempHorsepower = State(initialValue: baseCar.horsepower)
        _tempStage = State(initialValue: baseCar.stage)
        let initialSpecs = baseCar.specs.isEmpty
            ? VehicleEditorView.defaultSpecs()
            : VehicleEditorView.normalizedSpecs(baseCar.specs)
        _tempSpecs = State(initialValue: initialSpecs)
        _tempMods = State(initialValue: baseCar.mods)

        // Preselect presets based on saved mods titles and select all existing mod pills
        let presetSet = Self.presetSet
        let titles = Set(baseCar.mods.map { $0.title })
        let intersecting = titles.intersection(presetSet)
        _selectedPresetMods = State(initialValue: intersecting)
        _selectedModIDs = State(initialValue: Set(baseCar.mods.map { $0.id }))

        _tempVehicleClass = State(initialValue: baseCar.vehicleClass)

        // Load photo data from disk using photoFileName if available.
        if let photoFileName = baseCar.photoFileName, let loadedData = ImageStore.load(photoFileName) {
            _tempPhotoData = State(initialValue: loadedData)
        } else {
            _tempPhotoData = State(initialValue: nil)
        }

        _stageCarouselSelection = State(initialValue: baseCar.stage)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                RadialGradient(
                    gradient: Gradient(colors: [Color("EmpireMint").opacity(0.10), .clear]), // Reduced opacity
                    center: .topTrailing,
                    startRadius: 30,
                    endRadius: 450
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            switch step {
                            case .details:
                                stepOneView
                            case .modsSpecs:
                                stepTwoView
                            case .stage:
                                stepThreeView
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 32)
                        .padding(.top, 24)
                    }

                    bottomNavigation
                        .padding(.horizontal, 18)
                        .padding(.bottom, 16)
                }
                .padding(.top, 0)
            }
            .navigationTitle("Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .buttonStyle(.borderless)
                    .foregroundColor(Color("EmpireMint"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .fixedSize(horizontal: true, vertical: true)
                    .background(
                        Capsule()
                            .fill(Color.clear)
                    )
                    .frame(maxWidth: 120)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await loadSelectedPhoto(from: newValue)
            }
        }
    }

    // MARK: - Step 1 View (Vehicle Details: Image picker + Make, Model, Name)

    private var stepOneView: some View {
        VStack(spacing: 24) {
            
            EditorGlassCard {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color("EmpireMint").opacity(0.15))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.03)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.9
                                )
                        )
                        .shadow(color: Color("EmpireMint").opacity(0.2), radius: 8, x: 0, y: 3)
                        .frame(width: 110, height: 110)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        VStack(spacing: 6) {
                            if let data = tempPhotoData {
                                if let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .opacity(0.95)
                                } else {
                                    // If data is invalid, fallback
                                    fallbackImageViewRoundedSquare
                                }
                            } else if let photoFileName = car.photoFileName, let diskData = ImageStore.load(photoFileName), let uiImage = UIImage(data: diskData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .opacity(0.95)
                            } else {
                                fallbackImageViewRoundedSquare
                            }
                            Text("Tap to change image")
                                .font(.caption)
                                .foregroundColor(Color("EmpireMint").opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            // Basic fields card: Make, Model, Name
            EditorGlassCard {
                VStack(spacing: 16) {
                    GlassField(title: "Make", text: $tempMake)
                    GlassField(title: "Model", text: $tempModel)
                    GlassField(title: "Name", text: $tempName)
                }
            }

            // Vehicle Class card
            EditorGlassCard {
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
        }
    }

    // MARK: - Step 2 View (Mods and Specs)

    private var stepTwoView: some View {
        VStack(spacing: 24) {
            // Mods card
            EditorGlassCard {
                GlassSection(title: "Mods") {
                    QuickAddModsRow(selectedPresets: $selectedPresetMods)
                    let modGridColumns: [GridItem] = [GridItem(.adaptive(minimum: 140), spacing: 6)]
                    LazyVGrid(columns: modGridColumns, spacing: 6) {
                        ForEach(Array(tempMods.enumerated()).filter { !Self.presetSet.contains($0.element.title) }, id: \.element.id) { index, item in
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
            }

            // Specs card
            EditorGlassCard {
                GlassSection(title: "Specs & Horsepower") {
                    GlassNumberField(title: "Horsepower", value: $tempHorsepower, suffix: " WHP")
                    ForEach(tempSpecs, id: \.id) { spec in
                        HStack(spacing: 10) {
                            // Key pill
                            Text(spec.key.isEmpty ? "Engine" : spec.key)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .frame(width: 112)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.04)))
                                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                .foregroundStyle(.white)
                                .contentShape(Capsule())
                                .onTapGesture {
                                }

                            GlassTextField(placeholder: "Value", text: Binding(get: {
                                if let idx = tempSpecs.firstIndex(where: { $0.id == spec.id }) { return tempSpecs[idx].value } else { return "" }
                            }, set: { newVal in
                                if let idx = tempSpecs.firstIndex(where: { $0.id == spec.id }) { tempSpecs[idx].value = newVal }
                            }))
                            .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Step 3 View (Stage selection with justification and approval logic)

    private var stepThreeView: some View {
        VStack(spacing: 12) {
            Text("Stage Selection")
                .font(.title2.weight(.semibold))
                .foregroundColor(Color("EmpireMint"))
                .padding(.bottom, 8)

            let suggestedStage = computeSuggestedStage()

            Text("System Suggestion: \(suggestedStageText(for: suggestedStage))")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
                .italic()
                .padding(.bottom, 8)

            Text("Scroll to view all stage levels")
                .font(.footnote)
                .foregroundColor(Color("EmpireMint").opacity(0.7))
                .padding(.bottom, 4)

            TabView(selection: $stageCarouselSelection) {
                ForEach(0...3, id: \.self) { s in
                    StageCarouselCard(
                        stage: s,
                        isSelected: s == suggestedStage,
                        isSuggested: s == suggestedStage,
                        isPendingApproval: false,
                        accentColor: stageTint(for: s),
                        horsepowerRange: horsepowerRangeText(for: s),
                        description: stageDescription(for: s),
                        examples: stageExamples(for: s)
                    )
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .tag(s)
                    .onTapGesture {
                        if s != suggestedStage {
                            attemptedStageSelection = s
                            showStageWarning = true
                            stageCarouselSelection = s
                        } else {
                            stageCarouselSelection = s
                        }
                    }
                }
                StageCarouselCard(
                    stage: nil,
                    isSelected: false,
                    isSuggested: false,
                    isPendingApproval: false,
                    accentColor: Color.purple,
                    horsepowerRange: horsepowerRangeText(for: nil),
                    description: "Jailbreak mode disables stage selection and allows custom tuning beyond normal stages.",
                    examples: ["Custom engine swaps", "Extreme modifications"]
                )
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .tag(4)
                .onTapGesture {
                    attemptedStageSelection = 4
                    showStageWarning = true
                    stageCarouselSelection = 4
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 230)
            .padding(.bottom, 6)

            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .foregroundColor(stageCarouselSelection > 0 ? Color("EmpireMint") : Color("EmpireMint").opacity(0.3))
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(stageCarouselSelection < 4 ? Color("EmpireMint") : Color("EmpireMint").opacity(0.3))
                    .font(.headline)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 12)

            HStack(spacing: 6) {
                ForEach(0...4, id: \.self) { idx in
                    Circle()
                        .fill(idx == stageCarouselSelection ? Color("EmpireMint") : Color.white.opacity(0.25))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 12)

            if showStageWarning {
                EditorGlassCard {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color("EmpireMint"))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Selection doesn't match system suggestion")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Color("EmpireMint"))
                            let s = computeSuggestedStage()
                            let attempted = attemptedStageSelection ?? s
                            Text("You selected \(attempted == 4 ? "Jailbreak" : (attempted == 0 ? "Stock" : "Stage \(attempted)")). The system analyzed your mods and suggests \(s == 0 ? "Stock" : "Stage \(s)").")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                            Button(action: { showStageWarning = false; stageCarouselSelection = suggestedStage }) {
                                Text("Okay")
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color("EmpireMint")))
                                    .foregroundColor(.black)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut, value: stageCarouselSelection)
        .animation(.easeInOut, value: tempStage)
        .onChange(of: tempStage) { oldValue, newValue in
            let s = computeSuggestedStage()
            stageCarouselSelection = s
        }
        .onAppear {
            stageCarouselSelection = computeSuggestedStage()
        }
    }

    // MARK: - Bottom navigation buttons

    private var bottomNavigation: some View {
        HStack(spacing: 16) {
            switch step {
            case .details:
                // Step 1: Only Next button
                Button(action: { step = nextStep(from: step) }) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color("EmpireMint"))
                        )
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .modsSpecs:
                // Step 2: Back and Next side by side
                Button(action: { step = previousStep(from: step) }) {
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(Color("EmpireMint"), lineWidth: 1.3)
                        )
                        .foregroundColor(Color("EmpireMint"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(action: { step = nextStep(from: step) }) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color("EmpireMint"))
                        )
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .stage:
                // Step 3: Back and Save side by side
                Button(action: { step = previousStep(from: step) }) {
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(Color("EmpireMint"), lineWidth: 1.3)
                        )
                        .foregroundColor(Color("EmpireMint"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(action: { saveAndDismiss() }) {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(canSave() ? Color("EmpireMint") : Color.gray.opacity(0.5))
                        )
                        .foregroundColor(canSave() ? .black : Color.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .disabled(!canSave())
            }
        }
        .animation(.easeInOut, value: step)
    }
    private func previousStep(from step: Step) -> Step {
        switch step {
        case .details: return .details
        case .modsSpecs: return .details
        case .stage: return .modsSpecs
        }
    }
    private func nextStep(from step: Step) -> Step {
        switch step {
        case .details: return .modsSpecs
        case .modsSpecs: return .stage
        case .stage: return .stage
        }
    }

    private func canSave() -> Bool {

        return true
    }

    // MARK: - Helper: Compute suggested stage from current selections

    private func computeSuggestedStage() -> Int {
        // The suggestion is always from mods/specs, never affected by user's manual override including Jailbreak.
        // So always compute fresh suggestion ignoring tempIsJailbreak and tempStage.

        // Count preset mods and selected mod pills excluding presets
        let selectedPresetCount = selectedPresetMods.count
        let selectedModCount = tempMods.filter { selectedModIDs.contains($0.id) && !Self.presetSet.contains($0.title) }.count
        let totalSelectedCount = selectedPresetCount + selectedModCount

        // Check if any selected mod or preset contains "tune" (case-insensitive)
        let hasTuneFromPresets = selectedPresetMods.contains { $0.localizedCaseInsensitiveContains("tune") }
        let hasTuneFromSelectedMods = tempMods.contains { mod in
            selectedModIDs.contains(mod.id) && mod.title.localizedCaseInsensitiveContains("tune")
        }
        let hasTuneAny = hasTuneFromPresets || hasTuneFromSelectedMods

        guard hasTuneAny else {
            // No tune detected, suggest stage 0 by default
            return 0
        }

        if totalSelectedCount >= 6 {
            return 3
        } else if totalSelectedCount >= 4 {
            return 2
        } else if totalSelectedCount >= 2 {
            return 1
        } else {
            return 0
        }
    }

    private func suggestedStageText(for stage: Int) -> String {
        switch stage {
        case 0: return "Stock"
        case 1: return "Stage 1"
        case 2: return "Stage 2"
        case 3: return "Stage 3"
        default: return "Stock"
        }
    }

    private func stageDescription(for stage: Int) -> String {
        switch stage {
        case 0:
            return "Stock configuration with factory parts."
        case 1:
            return "Mild upgrades for improved performance."
        case 2:
            return "Significant modifications including major tuning."
        case 3:
            return "Extreme modifications with high performance parts."
        default:
            return ""
        }
    }

    private func horsepowerRangeText(for stage: Int?) -> String {
        switch stage {
        case 0:
            return "Typical range: 0-149 WHP"
        case 1:
            return "Typical range: 150-250 WHP"
        case 2:
            return "Typical range: 251-400 WHP"
        case 3:
            return "Typical range: 401+ WHP"
        case nil:
            return ""
        default:
            return "Typical range varies"
        }
    }

    private func stageExamples(for stage: Int) -> [String] {
        switch stage {
        case 0: return ["Factory intake", "Stock exhaust", "No tuning"]
        case 1: return ["Basic tune", "Performance exhaust", "Upgraded intake"]
        case 2: return ["Aggressive tuning", "Forced induction", "Built motor"]
        case 3: return ["Race-level tune", "Full motor swap", "Pro-level forced induction"]
        default: return []
        }
    }

    // MARK: - Save & Dismiss

    private func saveAndDismiss() {
        var updated = car
        updated.name = tempName
        updated.description = tempDescription
        updated.make = tempMake
        updated.model = tempModel
        updated.imageName = tempImageName
        updated.horsepower = tempHorsepower
        updated.specs = tempSpecs

        updated.mods = tempMods

        // Merge selected preset pills into saved mods without duplicating in the editor grid
        let existingTitles = Set(updated.mods.map { $0.title })
        let presetsToPersist = selectedPresetMods.subtracting(existingTitles)
        if !presetsToPersist.isEmpty {
            let newPresetItems = presetsToPersist.map { title in
                ModItem(title: title, notes: "", isMajor: true)
            }
            updated.mods.append(contentsOf: newPresetItems)
        }

        // Remove any preset mods that are no longer selected
        updated.mods.removeAll { item in
            Self.presetSet.contains(item.title) && !selectedPresetMods.contains(item.title)
        }

        updated.vehicleClass = tempVehicleClass

        // Persist photo data to disk and update photoFileName accordingly
        if let data = tempPhotoData {
            let filename = "car_\(updated.id.uuidString).jpg"
            do {
                let compressed = compressForLocalStorage(data) ?? data
                _ = try ImageStore.save(compressed, fileName: filename)
                updated.photoFileName = filename
            } catch {
                // On failure, do not update photoFileName
            }
        }

        // Apply suggested stage directly, no jailbreak or pending overrides
        let suggested = computeSuggestedStage()
        updated.stage = suggested
        updated.isJailbreak = false

        // Persist per-user so edits survive relaunch.
        Self.saveCar(updated, userKey: userStorageKey)

        LocalStore.shared.upsertCar(updated, context: modelContext, userKey: userStorageKey)

        onSave(updated)
        dismiss()
    }

    // MARK: - Helpers & fallback

    private var fallbackImageView: some View {
        Image(tempImageName)
            .resizable()
            .scaledToFit()
            .frame(height: 100)
            .opacity(0.9)
    }
    private var fallbackImageViewRoundedSquare: some View {
        Image(tempImageName)
            .resizable()
            .scaledToFill()
            .frame(width: 110, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(0.9)
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

    private static func normalizedSpecs(_ specs: [SpecItem]) -> [SpecItem] {
        let preferredSpecOrder: [String] = ["engine", "drivetrain", "transmission", "tires", "weight"]
        let rank = Dictionary(uniqueKeysWithValues: preferredSpecOrder.enumerated().map { ($1, $0) })
        return specs.sorted { lhs, rhs in
            let leftRank = rank[lhs.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? Int.max
            let rightRank = rank[rhs.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? Int.max
            if leftRank != rightRank { return leftRank < rightRank }
            return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }
    }

    private func bindingForMod(id: UUID) -> Binding<ModItem>? {
        guard let idx = tempMods.firstIndex(where: { $0.id == id }) else { return nil }
        return $tempMods[idx]
    }

    // MARK: - Persistence (UserDefaults)

    private static func carStorageKey(for id: UUID, userKey: String) -> String {
        "saved_car_\(userKey)_\(id.uuidString)"
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

    private func loadSelectedPhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run {
                self.tempPhotoData = compressForLocalStorage(data) ?? data
            }
        } catch {
            // Ignore picker errors and keep previous image state.
        }
    }

    private func compressForLocalStorage(_ data: Data) -> Data? {
        let maxBytes = 1_500_000
        guard data.count > maxBytes else { return data }
        guard let image = UIImage(data: data) else { return data }

        var compression: CGFloat = 0.94
        var result = image.jpegData(compressionQuality: compression)

        while let current = result, current.count > maxBytes, compression > 0.5 {
            compression -= 0.08
            result = image.jpegData(compressionQuality: compression)
        }

        return result ?? data
    }
}

// MARK: - StageCarouselCard for horizontal carousel UI

private struct StageCarouselCard: View {
    let stage: Int?
    let isSelected: Bool
    let isSuggested: Bool
    let isPendingApproval: Bool
    let accentColor: Color
    let horsepowerRange: String
    let description: String
    let examples: [String]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(stageTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(accentColor)
                    if isSuggested {
                        Image(systemName: "star.fill")
                            .foregroundColor(accentColor)
                            .font(.caption)
                            .accessibilityLabel("System Suggestion")
                    }
                    Spacer()
                }
                if !horsepowerRange.isEmpty {
                    Text(horsepowerRange)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accentColor.opacity(0.85))
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                if !examples.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Examples:")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(accentColor.opacity(0.8))
                        ForEach(examples, id: \.self) { example in
                            Text("• \(example)")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                }
                Spacer()
            }
            .padding(16)
            .frame(width: 260, height: 220)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color("EmpireMint").opacity(isSelected ? 0.35 : 0.14))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? accentColor.opacity(0.9) : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(color: accentColor.opacity(isSelected ? 0.6 : 0), radius: 10, x: 0, y: 6)
            )
            if isPendingApproval {
                Text("Pending Approval")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.85))
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                    .padding(10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var stageTitle: String {
        if let s = stage {
            switch s {
            case 0: return "Stock"
            case 1: return "Stage 1"
            case 2: return "Stage 2"
            case 3: return "Stage 3"
            default: return "Stage \(s)"
            }
        } else {
            return "Jailbreak"
        }
    }
}

// MARK: - Subviews

private struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(Color("EmpireMint"))
            VStack(spacing: 8) {
                content
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color("EmpireMint").opacity(0.10))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.9
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
        VStack(alignment: .leading, spacing: 6) {
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
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color("EmpireMint").opacity(0.10))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
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
        VStack(alignment: .leading, spacing: 6) {
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
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 6) {
                if !suffix.isEmpty {
                    Text(suffix)
                        .foregroundColor(.clear)
                        .font(.footnote)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 40, alignment: .leading)
                        .accessibilityHidden(true)
                }
                TextField(title, value: $value, formatter: NumberFormatter())
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(width: 140)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.9))
                    .foregroundColor(.white)
                if !suffix.isEmpty {
                    Text(suffix)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.footnote)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 40, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .offset(x: -6)
        }
    }
}

private struct QuickAdjustRow: View {
    let adjustments: [Int]
    var onAdjust: (Int) -> Void
    var body: some View {
        HStack(spacing: 8) {
            ForEach(adjustments, id: \.self) { delta in
                Button(action: { onAdjust(delta) }) {
                    Text("+\(delta)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.9))
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Stage").font(.footnote).foregroundColor(.white.opacity(0.8))
            HStack(spacing: 6) {
                ForEach(0...3, id: \.self) { s in
                    Button(action: { isJailbreak = false; stage = s }) {
                        Text(s == 0 ? "Stock" : "Stage \(s)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.ultraThinMaterial))
                            .overlay(
                                Capsule().stroke(
                                    (stage == s && !isJailbreak) ? stageTint(for: s).opacity(0.8) : Color.white.opacity(0.2),
                                    lineWidth: 0.9
                                )
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: { isJailbreak = true }) {
                    Text("Jailbreak")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(isJailbreak ? Color.purple.opacity(0.8) : Color.white.opacity(0.2), lineWidth: 0.9))
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
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { (p: String) in
                    let isSelected = selectedPresets.contains(p)
                    Button(action: {
                        if isSelected { selectedPresets.remove(p) } else { selectedPresets.insert(p) }
                    }) {
                        Text(p)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(isSelected ? Color.green.opacity(0.18) : Color.white.opacity(0.04))
                            )
                            .overlay(
                                Capsule().stroke(
                                    isSelected ? Color.green.opacity(0.8) : Color.white.opacity(0.2),
                                    lineWidth: 0.9
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
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AnimatedMintGradient(phase: animatePhase), lineWidth: 1.8)
                )
                .padding(.horizontal, 20)
                .shadow(color: Color("EmpireMint").opacity(0.25), radius: 10, x: 0, y: 6)
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
        let loc1 = fmod(phase - 0.2 + 1, 1)
        let loc2 = fmod(phase + 0.0 + 1, 1)
        let loc3 = fmod(phase + 0.2 + 1, 1)

        let stops = [
            (location: loc1, color: Color("EmpireMint").opacity(0.15)),
            (location: loc2, color: Color("EmpireMint").opacity(0.7)),
            (location: loc3, color: Color("EmpireMint").opacity(0.15))
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
        HStack(spacing: 8) {
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
        HStack(spacing: 8) {
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
        HStack(spacing: 4) {
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(isSelected ? Color.green.opacity(0.18) : Color.white.opacity(0.04)) 
        )
        .overlay(
            Group {
                if isSelected {
                    Capsule().stroke(Color.green.opacity(0.8), lineWidth: 0.9)
                } else {
                    Capsule().stroke(
                        LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.9
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
