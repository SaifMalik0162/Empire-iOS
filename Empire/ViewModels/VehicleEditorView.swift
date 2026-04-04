import SwiftUI
import PhotosUI
import UIKit
import SwiftData
import CryptoKit

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
        case vehicleClass
        case buildCategory
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
    @State private var tempBuildCategory: BuildCategory?

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var tempPhotoData: Data? = nil
    @State private var originalPhotoFingerprint: String?
    @State private var tempPhotoFingerprint: String?

    private let userStorageKey: String

    @State private var selectedModIDs: Set<UUID> = []
    @State private var selectedPresetMods: Set<String> = []

    @State private var stageCarouselSelection: Int = 0

    private static let presetSet: Set<String> = [
        "Tune", "Intake", "Headers", "Exhaust",
        "Forced Induction", "Motor Swap", "Drivetrain Swap", "Transmission Upgrades", "Built Motor"
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

        // Preset mods are driven only by the quick-select pills. Keep custom mods in the grid.
        let presetSet = Self.presetSet
        let titles = Set(baseCar.mods.compactMap { Self.normalizePresetTitle($0.title) })
        let intersecting = titles.intersection(presetSet)
        let customMods = baseCar.mods.filter { !Self.isPresetModTitle($0.title) }
        _tempMods = State(initialValue: customMods)
        _selectedPresetMods = State(initialValue: intersecting)
        _selectedModIDs = State(initialValue: Set(customMods.map { $0.id }))

        _tempVehicleClass = State(initialValue: baseCar.vehicleClass)
        _tempBuildCategory = State(initialValue: baseCar.buildCategory)

        // Load photo data from disk using photoFileName if available.
        if let photoFileName = baseCar.photoFileName, let loadedData = ImageStore.load(photoFileName) {
            _tempPhotoData = State(initialValue: loadedData)
            let fingerprint = Self.photoFingerprint(for: loadedData)
            _originalPhotoFingerprint = State(initialValue: fingerprint)
            _tempPhotoFingerprint = State(initialValue: fingerprint)
        } else {
            _tempPhotoData = State(initialValue: nil)
            _originalPhotoFingerprint = State(initialValue: nil)
            _tempPhotoFingerprint = State(initialValue: nil)
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
                            case .vehicleClass:
                                classStepView
                            case .buildCategory:
                                categoryStepView
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
        .onAppear {
            ensureQuarterMileSpecMatchesClass()
        }
        .onChange(of: tempVehicleClass) { _, _ in
            ensureQuarterMileSpecMatchesClass()
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

        }
    }

    private var classStepView: some View {
        VStack(spacing: 24) {
            EditorGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vehicle Class")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color("EmpireMint"))

                    Text("Choose the class first. The stage system evaluates power relative to the class, and Class D uses quarter-mile results instead of the normal ladder.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(VehicleClass.allCases) { cls in
                                VehicleClassCard(vehicleClass: cls, isSelected: tempVehicleClass == cls)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                            tempVehicleClass = cls
                                            ensureQuarterMileSpecMatchesClass()
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
    }

    private var categoryStepView: some View {
        VStack(spacing: 24) {
            EditorGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Build Category")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color("EmpireMint"))

                    Text("Add the badge that best fits the stance or purpose of the build. Leave it blank if you do not want a category emblem on posts.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        BuildCategoryOptionCard(
                            title: "No Specification",
                            subtitle: "No emblem will be shown on posts.",
                            category: nil,
                            isSelected: tempBuildCategory == nil
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                tempBuildCategory = nil
                            }
                        }

                        ForEach(BuildCategory.allCases) { category in
                            BuildCategoryOptionCard(
                                title: category.title,
                                subtitle: category.subtitle,
                                category: category,
                                isSelected: tempBuildCategory == category
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    tempBuildCategory = category
                                }
                            }
                        }
                    }
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
                        ForEach(Array(tempMods.enumerated()).filter { !Self.isPresetModTitle($0.element.title) }, id: \.element.id) { index, item in
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
        let assessment = computeStageAssessment()
        let selectedClass = tempVehicleClass
        let stageColor = StageSystem.accentColor(for: assessment.stage.rawValue, isJailbreak: assessment.isJailbreak)

        return VStack(spacing: 16) {
            Text("Stage Assessment")
                .font(.title2.weight(.semibold))
                .foregroundColor(Color("EmpireMint"))
                .padding(.bottom, 8)

            EditorGlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [stageColor.opacity(0.24), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(stageColor.opacity(0.45), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 12) {
                            Text(selectedClass.map { "Class \($0.code) • \($0.displayName)" } ?? "No class selected")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.74))

                            Text(StageSystem.displayLabel(for: assessment.stage.rawValue, isJailbreak: assessment.isJailbreak).uppercased())
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(stageColor)

                            Text(assessment.summary)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(assessment.detail)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                    }
                    .frame(maxWidth: .infinity, minHeight: 190)

                    HStack(spacing: 10) {
                        stageGatePill(title: "Major Mods", value: "\(assessment.majorModCount)/\(StageSystem.requiredMajorModCount)", isPassing: assessment.majorModCount >= StageSystem.requiredMajorModCount)
                        stageGatePill(title: "Tune", value: assessment.hasTune ? "Detected" : "Missing", isPassing: assessment.hasTune)
                        stageGatePill(title: tempVehicleClass == .dragTrack ? "1/4 Mile" : "WHP", value: tempVehicleClass == .dragTrack ? quarterMileDisplayValue : "\(tempHorsepower)", isPassing: tempVehicleClass == .dragTrack ? !quarterMileValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : true)
                    }
                }
            }

            if let selectedClass, selectedClass == .dragTrack {
                EditorGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Class \(selectedClass.code) Quarter-Mile Ladder")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedClass.accentColor)

                        ForEach(StageSystem.dragTrackStageBands, id: \.rank) { band in
                            HStack {
                                Text(band.rank.label)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(band.rank.accentColor)
                                Spacer()
                                Text(band.elapsedTimeLabel)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(band.rank == assessment.stage ? band.rank.accentColor.opacity(0.16) : Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(band.rank == assessment.stage ? band.rank.accentColor.opacity(0.8) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                }
            } else if let selectedClass, !selectedClass.stageBands.isEmpty {
                EditorGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Class \(selectedClass.code) Stage Ladder")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedClass.accentColor)

                        ForEach(selectedClass.stageBands, id: \.rank) { band in
                            HStack {
                                Text(band.rank.label)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(band.rank.accentColor)
                                Spacer()
                                Text(band.horsepowerLabel)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(band.rank == assessment.stage ? band.rank.accentColor.opacity(0.16) : Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(band.rank == assessment.stage ? band.rank.accentColor.opacity(0.8) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            EditorGlassCard {
                GlassSection(title: "Build Readiness") {
                    let selectedMods = selectedMajorModTitles()

                    VStack(alignment: .leading, spacing: 10) {
                        readinessRow(
                            title: "Major mod gate",
                            detail: "A build stays Stock until at least 3 major mods are selected.",
                            isPassing: assessment.majorModCount >= StageSystem.requiredMajorModCount
                        )
                        readinessRow(
                            title: "Tune required",
                            detail: assessment.hasTune ? "Tune detected in the selected setup." : "Add a tune before the build can move out of Stock.",
                            isPassing: assessment.hasTune
                        )

                        if tempVehicleClass == .dragTrack {
                            readinessRow(
                                title: "Quarter-mile required",
                                detail: quarterMileValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "Enter the fastest recorded 1/4 mile run for Class D."
                                    : "Recorded run: \(quarterMileValue)",
                                isPassing: !quarterMileValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                        }

                        if !selectedMods.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selected Major Mods")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.82))

                                FlexiblePillWrap(items: selectedMods) { mod in
                                    Text(mod)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.white.opacity(0.07)))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            stageCarouselSelection = assessment.stage.rawValue
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
            case .vehicleClass:
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
            case .buildCategory:
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
        case .vehicleClass: return .details
        case .buildCategory: return .vehicleClass
        case .modsSpecs: return .buildCategory
        case .stage: return .modsSpecs
        }
    }
    private func nextStep(from step: Step) -> Step {
        switch step {
        case .details: return .vehicleClass
        case .vehicleClass: return .buildCategory
        case .buildCategory: return .modsSpecs
        case .modsSpecs: return .stage
        case .stage: return .stage
        }
    }

    private func canSave() -> Bool {
        if tempVehicleClass == .dragTrack {
            return !quarterMileValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    // MARK: - Helper: Compute stage from class, horsepower, and qualifying mods

    private func computeStageAssessment() -> StageAssessment {
        StageSystem.assessment(
            vehicleClass: tempVehicleClass,
            horsepower: tempHorsepower,
            selectedMajorMods: selectedMajorModTitles(),
            quarterMile: quarterMileValue
        )
    }

    private func selectedMajorModTitles() -> [String] {
        let presetMods = selectedPresetMods.filter { StageSystem.isMajorMod($0) }
        let selectedCustomMods = tempMods.compactMap { mod -> String? in
            guard selectedModIDs.contains(mod.id) else { return nil }
            guard Self.isPresetModTitle(mod.title) == false else { return nil }
            return StageSystem.isMajorMod(mod.title, isMajorFlag: mod.isMajor) ? mod.title : nil
        }
        return Array(Set(presetMods + selectedCustomMods)).sorted()
    }

    private func stageGatePill(title: String, value: String, isPassing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle((isPassing ? Color("EmpireMint") : Color.orange).opacity(0.9))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((isPassing ? Color("EmpireMint") : Color.orange).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke((isPassing ? Color("EmpireMint") : Color.orange).opacity(0.35), lineWidth: 1)
        )
    }

    private func readinessRow(title: String, detail: String, isPassing: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isPassing ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.headline)
                .foregroundStyle(isPassing ? Color("EmpireMint") : Color.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((isPassing ? Color("EmpireMint") : Color.orange).opacity(0.22), lineWidth: 1)
        )
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

        updated.mods = tempMods.filter { !Self.isPresetModTitle($0.title) }

        // Merge selected preset pills into saved mods without duplicating in the editor grid
        let existingPresetTitles = Set(updated.mods.compactMap { Self.normalizePresetTitle($0.title) })
        let presetsToPersist = selectedPresetMods.subtracting(existingPresetTitles)
        if !presetsToPersist.isEmpty {
            let newPresetItems = presetsToPersist.map { title in
                ModItem(title: title, notes: "", isMajor: true)
            }
            updated.mods.append(contentsOf: newPresetItems)
        }

        // Remove any preset mods that are no longer selected
        updated.mods.removeAll { item in
            guard let normalizedTitle = Self.normalizePresetTitle(item.title) else { return false }
            return !selectedPresetMods.contains(normalizedTitle)
        }

        updated.vehicleClass = tempVehicleClass
        updated.buildCategory = tempBuildCategory
        updated.specs = syncedSpecsForSave()

        let assessment = computeStageAssessment()
        updated.stage = assessment.stage.rawValue
        updated.isJailbreak = assessment.isJailbreak

        let photoDataToWrite = tempPhotoData
        let photoDidChange = tempPhotoFingerprint != originalPhotoFingerprint
        let userStorageKey = self.userStorageKey
        let modelContext = self.modelContext

        Task(priority: .userInitiated) {
            var finalized = updated

            if photoDidChange, let photoDataToWrite {
                let filename = "car_\(finalized.id.uuidString).jpg"
                do {
                    _ = try ImageStore.save(photoDataToWrite, fileName: filename)
                    finalized.photoFileName = filename
                } catch {
                    // On failure, keep the previous photoFileName.
                }
            }

            await MainActor.run {
                Self.saveCar(finalized, userKey: userStorageKey)
                LocalStore.shared.upsertCar(finalized, context: modelContext, userKey: userStorageKey)
                onSave(finalized)
                dismiss()
            }
        }
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
        let preferredSpecOrder: [String] = ["engine", "drivetrain", "transmission", "tires", "weight", "1/4 mile"]
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

    private static func photoFingerprint(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func labelForClass(_ cls: VehicleClass) -> String {
        cls.rawValue
    }

    private var quarterMileValue: String {
        tempSpecs.first(where: { normalizedSpecKey($0.key) == "1/4 mile" })?.value ?? ""
    }

    private var quarterMileDisplayValue: String {
        let value = quarterMileValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Needed" : value
    }

    private func normalizedSpecKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func ensureQuarterMileSpecMatchesClass() {
        if tempVehicleClass == .dragTrack {
            if tempSpecs.contains(where: { normalizedSpecKey($0.key) == "1/4 mile" }) == false {
                tempSpecs.append(SpecItem(key: "1/4 Mile", value: ""))
                tempSpecs = Self.normalizedSpecs(tempSpecs)
            }
        } else {
            tempSpecs.removeAll { normalizedSpecKey($0.key) == "1/4 mile" }
        }
    }

    private func updateQuarterMileSpec(_ value: String) {
        if let index = tempSpecs.firstIndex(where: { normalizedSpecKey($0.key) == "1/4 mile" }) {
            tempSpecs[index].value = value
        } else {
            tempSpecs.append(SpecItem(key: "1/4 Mile", value: value))
        }
        tempSpecs = Self.normalizedSpecs(tempSpecs)
    }

    private func syncedSpecsForSave() -> [SpecItem] {
        var specs = tempSpecs
        if tempVehicleClass == .dragTrack {
            if let index = specs.firstIndex(where: { normalizedSpecKey($0.key) == "1/4 mile" }) {
                specs[index].key = "1/4 Mile"
            } else {
                specs.append(SpecItem(key: "1/4 Mile", value: quarterMileValue))
            }
        } else {
            specs.removeAll { normalizedSpecKey($0.key) == "1/4 mile" }
        }
        return Self.normalizedSpecs(specs)
    }

    private static func normalizePresetTitle(_ title: String) -> String? {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "tune": return "Tune"
        case "intake", "intake manifold": return "Intake"
        case "headers": return "Headers"
        case "exhaust", "performance exhaust": return "Exhaust"
        case "forced induction", "forced induction kit": return "Forced Induction"
        case "motor swap": return "Motor Swap"
        case "drivetrain swap": return "Drivetrain Swap"
        case "transmission upgrade", "transmission upgrades": return "Transmission Upgrades"
        case "built motor": return "Built Motor"
        default: return nil
        }
    }

    private static func isPresetModTitle(_ title: String) -> Bool {
        normalizePresetTitle(title) != nil
    }

    private func loadSelectedPhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let processedData = await Self.preparePhotoForLocalStorage(data)
            let fingerprint = Self.photoFingerprint(for: processedData)
            await MainActor.run {
                self.tempPhotoData = processedData
                self.tempPhotoFingerprint = fingerprint
            }
        } catch {
            // Ignore picker errors and keep previous image state.
        }
    }

    private nonisolated static func preparePhotoForLocalStorage(_ data: Data) async -> Data {
        await Task.detached(priority: .userInitiated) {
            compressForLocalStorage(data) ?? data
        }.value
    }

    private nonisolated static func compressForLocalStorage(_ data: Data) -> Data? {
        let maxBytes = 1_500_000
        let maxDimension: CGFloat = 1600

        guard let image = UIImage(data: data) else { return data }

        let resizedImage = resizedImageIfNeeded(image, maxDimension: maxDimension)
        let inputImage = resizedImage ?? image

        if let jpeg = inputImage.jpegData(compressionQuality: 0.92), jpeg.count <= maxBytes {
            return jpeg
        }

        var compression: CGFloat = 0.94
        var result = inputImage.jpegData(compressionQuality: compression)

        while let current = result, current.count > maxBytes, compression > 0.5 {
            compression -= 0.08
            result = inputImage.jpegData(compressionQuality: compression)
        }

        return result ?? data
    }

    private nonisolated static func resizedImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return nil }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let majorModsCount: Int
    let hasTune: Bool
    var onApply: () -> Void
    @State private var animatePhase: CGFloat = 0
    @State private var isAnimating = false

    private var animationsEnabled: Bool {
        scenePhase == .active && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

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
                .onAppear { updateAnimationState() }
                .onChange(of: animationsEnabled) { _, _ in updateAnimationState() }
                .onDisappear { stopAnimation() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func updateAnimationState() {
        animationsEnabled ? startAnimation() : stopAnimation()
    }

    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        animatePhase = 0
        withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
            animatePhase = 1
        }
    }

    private func stopAnimation() {
        guard isAnimating || animatePhase != 0 else { return }
        isAnimating = false
        animatePhase = 0
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

private struct FlexiblePillWrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    init(items: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let rows = makeRows(from: Array(items))
            ForEach(Array(rows.enumerated()), id: \.offset) { entry in
                let row = entry.element
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func makeRows(from items: [Data.Element]) -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        for item in items {
            if rows[rows.count - 1].count >= 2 {
                rows.append([item])
            } else {
                rows[rows.count - 1].append(item)
            }
        }
        return rows.filter { !$0.isEmpty }
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
