import SwiftUI
import PhotosUI

struct ShareToFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    let userCars: [Car]
    var preselectedIndex: Int = 0
    var onPosted: ((CommunityPost) -> Void)?

    @StateObject private var communityVM = CommunityViewModel()

    @State private var selectedCarIndex: Int = 0
    @State private var caption: String = ""
    @State private var isPosting = false
    @State private var errorMessage: String? = nil
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var overridePhotoDataList: [Data] = []
    @State private var selectedPrompt: FeedCaptionPrompt? = nil
    @State private var lastAutofillText: String? = nil
    @State private var upcomingMeets: [Meet] = []
    @State private var selectedMeetID: UUID? = nil
    @State private var selectedChallengeID: String? = CommunityProgrammingChallenge.current().id
    @State private var isLoadingMeets = false

    private let meetsService = SupabaseMeetsService()

    private var selectedCar: Car? { userCars[safe: selectedCarIndex] }
    private var captionTrimmed: String { caption.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var selectedPromptTitle: String {
        selectedPrompt?.title ?? "Tell the story behind this build"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if userCars.isEmpty {
                            noCarsView
                        } else {
                            introCard
                            carPickerSection
                            photoOverrideSection
                            programmingSection
                            captionSection
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption).foregroundStyle(.red.opacity(0.9))
                                .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Share to Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: sharePost) {
                        if isPosting {
                            ProgressView().tint(Color("EmpireMint")).scaleEffect(0.85)
                        } else {
                            Text("Post").fontWeight(.semibold).foregroundStyle(Color("EmpireMint"))
                        }
                    }
                    .disabled(isPosting || selectedCar == nil)
                }
            }
        }
        .onAppear {
            // Pre-select the car the user was looking at in the garage carousel
            selectedCarIndex = min(preselectedIndex, max(0, userCars.count - 1))
            loadUpcomingMeets()
        }
        .onChange(of: selectedCarIndex) { _, _ in
            refreshAutofillForCurrentSelection()
        }
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else {
                overridePhotoDataList = []
                return
            }
            Task {
                var loaded: [Data] = []
                for item in items.prefix(5) {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append(data)
                    }
                }
                await MainActor.run { overridePhotoDataList = loaded }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - No cars

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color("EmpireMint"))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color("EmpireMint").opacity(0.14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Builds with context get more love")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("A quick note about what changed, why it matters, or what you're chasing gives people a reason to jump in.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
        }
        .glassCard()
    }

    private var noCarsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "car.fill")
                .font(.system(size: 42)).foregroundStyle(Color("EmpireMint").opacity(0.5))
            Text("No vehicles in your garage")
                .font(.headline).foregroundStyle(.white)
            Text("Add a car to your garage first, then you can share it to the community feed.")
                .font(.caption).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
        }
        .padding(24).glassCard()
    }

    // MARK: - Car picker

    private var carPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Select vehicle")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color("EmpireMint"))
                Spacer()
                Text("\(selectedCarIndex + 1) of \(userCars.count)")
                    .font(.caption2).foregroundStyle(.white.opacity(0.4))
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(userCars.indices, id: \.self) { idx in
                        ShareVehicleRow(
                            car: userCars[idx],
                            isSelected: idx == selectedCarIndex,
                            overridePhotoData: idx == selectedCarIndex ? overridePhotoDataList.first : nil
                        )
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedCarIndex = idx
                            }
                        }
                    }
                }
            }
            .frame(height: min(CGFloat(userCars.count) * 82, 205))

            if userCars.count > 2 {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color("EmpireMint").opacity(0.5))
                    Text("Scroll to see all vehicles")
                        .font(.caption2).foregroundStyle(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .glassCard()
    }

    // MARK: - Photo override

    private var programmingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Programming")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("EmpireMint"))
                Spacer()
                if let selectedChallenge {
                    Text(selectedChallenge.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(selectedChallenge.accentColor)
                        .lineLimit(1)
                }
            }

            currentChallengeCard

            if isLoadingMeets {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color("EmpireMint"))
                    Text("Loading upcoming meets…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            } else if !upcomingMeets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Link A Meet")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.58))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            meetLinkChip(meet: nil, label: "No Meet")
                            ForEach(Array(upcomingMeets.prefix(4))) { meet in
                                meetLinkChip(meet: meet, label: meet.title)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
        .glassCard()
    }

    private var currentChallengeCard: some View {
        let challenge = selectedChallenge ?? CommunityProgrammingChallenge.current()

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedChallengeID = selectedChallengeID == challenge.id ? nil : challenge.id
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(challenge.accentColor.opacity(0.16))
                    Image(systemName: challenge.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(challenge.accentColor)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    Text(challenge.composerPrompt)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(selectedChallengeID == challenge.id ? "On" : "Add")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(selectedChallengeID == challenge.id ? challenge.accentColor : .white.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(challenge.accentColor.opacity(selectedChallengeID == challenge.id ? 0.12 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(challenge.accentColor.opacity(selectedChallengeID == challenge.id ? 0.45 : 0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var photoOverrideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("EmpireMint"))
                Spacer()
                Text(overridePhotoDataList.isEmpty ? "Using garage photo" : "\(overridePhotoDataList.count) selected")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(overridePhotoDataList.isEmpty ? .white.opacity(0.42) : Color("EmpireMint"))
            }

            ZStack(alignment: .bottomLeading) {
                coverPreview
                    .frame(height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(overridePhotoDataList.isEmpty ? "Current cover photo" : "Updated cover photo")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color("EmpireMint"))

                        Text(overridePhotoDataList.isEmpty
                             ? "Pulled from the build already saved in your garage."
                             : "The first selected image will lead the post.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    if !overridePhotoDataList.isEmpty {
                        Text("COVER")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color("EmpireMint").opacity(0.32)))
                            .overlay(Capsule().stroke(Color("EmpireMint").opacity(0.65), lineWidth: 1))
                    }
                }
                .padding(14)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: overridePhotoDataList.isEmpty ? "photo.badge.plus" : "photo.on.rectangle.angled")
                            .font(.system(size: 13, weight: .semibold))
                        Text(overridePhotoDataList.isEmpty ? "Choose photos" : "Replace photos")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                }

                if !overridePhotoDataList.isEmpty {
                    Button {
                        overridePhotoDataList = []
                        selectedPhotoItems = []
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Reset")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !overridePhotoDataList.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(overridePhotoDataList.enumerated()), id: \.offset) { pair in
                            if let ui = UIImage(data: pair.element) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 66, height: 66)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(pair.offset == 0 ? Color("EmpireMint").opacity(0.65) : Color.white.opacity(0.12), lineWidth: 1)
                                        )

                                    if pair.offset == 0 {
                                        Text("COVER")
                                            .font(.system(size: 8, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color("EmpireMint"))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(.ultraThinMaterial))
                                            .padding(6)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text("Choose up to 5 photos. The first one becomes the cover.")
                .font(.caption2).foregroundStyle(.white.opacity(0.4))
        }
        .glassCard()
    }

    // MARK: - Caption

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Caption")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("EmpireMint"))
                Spacer()
                Text(selectedPromptTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FeedCaptionPrompt.allCases, id: \.self) { prompt in
                            promptChip(prompt)
                        }
                    }
                    .padding(.vertical, 1)
                }

                if let selectedPrompt {
                    Text(selectedPrompt.editorHint)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .transition(.opacity)
                }
            }

            ZStack(alignment: .topLeading) {
                if caption.isEmpty {
                    Text(placeholderText)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 10).padding(.leading, 14)
                }
                TextEditor(text: $caption)
                    .scrollContentBackground(.hidden).background(Color.clear)
                    .foregroundStyle(.white).font(.subheadline)
                    .frame(minHeight: 80, maxHeight: 160)
                    .padding(.horizontal, 10).padding(.vertical, 4)
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))

            Text("\(caption.count)/280")
                .font(.caption2).foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .glassCard()
        .onChange(of: caption) { _, new in
            if new.count > 280 { caption = String(new.prefix(280)) }
            if let lastAutofillText, new != lastAutofillText {
                self.lastAutofillText = nil
            }
        }
    }

    private var placeholderText: String {
        selectedPrompt?.placeholder ?? "Add a caption… (optional)"
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let data = overridePhotoDataList.first, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else if let car = selectedCar,
                  let fileName = car.photoFileName,
                  let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                  let data = try? Data(contentsOf: dir.appendingPathComponent(fileName)),
                  let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else if let selectedCar {
            Image(selectedCar.imageName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.white.opacity(0.05)
                Image(systemName: "photo")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
    }

    private func promptChip(_ prompt: FeedCaptionPrompt) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            applyPrompt(prompt)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: prompt.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(prompt.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selectedPrompt == prompt ? prompt.tint : .white.opacity(0.72))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selectedPrompt == prompt ? prompt.tint.opacity(0.18) : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(selectedPrompt == prompt ? prompt.tint.opacity(0.7) : Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share action

    private func sharePost() {
        guard let car = selectedCar else { return }
        isPosting = true
        errorMessage = nil

        Task {
            do {
                let post = try await communityVM.sharePost(
                    car: car,
                    caption: captionTrimmed.isEmpty ? nil : captionTrimmed,
                    photoDataList: overridePhotoDataList.isEmpty ? loadDefaultPhotoDataList(for: car) : overridePhotoDataList,
                    metadata: postMetadata
                )
                await MainActor.run {
                    isPosting = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onPosted?(post)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    errorMessage = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func loadDefaultPhotoDataList(for car: Car) -> [Data]? {
        guard let fileName = car.photoFileName,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(fileName)) else { return nil }
        return [data]
    }

    private func applyPrompt(_ prompt: FeedCaptionPrompt) {
        if selectedPrompt == prompt {
            selectedPrompt = nil
            if let lastAutofillText, caption == lastAutofillText {
                caption = ""
            }
            lastAutofillText = nil
            return
        }

        let buildName = selectedCar?.name ?? "this build"
        let nextText = prompt.seedText(for: buildName)

        if let lastAutofillText, caption == lastAutofillText || captionTrimmed.isEmpty {
            caption = nextText
            self.lastAutofillText = nextText
        } else if captionTrimmed.isEmpty {
            caption = nextText
            self.lastAutofillText = nextText
        }

        selectedPrompt = prompt
    }

    private func refreshAutofillForCurrentSelection() {
        guard let selectedPrompt, let lastAutofillText, caption == lastAutofillText else { return }
        let updated = selectedPrompt.seedText(for: selectedCar?.name ?? "this build")
        caption = updated
        self.lastAutofillText = updated
    }

    private var selectedChallenge: CommunityProgrammingChallenge? {
        guard let selectedChallengeID else { return nil }
        return CommunityProgrammingChallenge(rawValue: selectedChallengeID)
    }

    private var postMetadata: CommunityPostProgramMetadata? {
        let linkedMeet = upcomingMeets.first(where: { $0.id == selectedMeetID })
        let metadata = CommunityPostProgramMetadata(
            challengeID: selectedChallenge?.id,
            linkedMeetId: linkedMeet?.id,
            linkedMeetTitle: linkedMeet?.title
        )
        return metadata.isEmpty ? nil : metadata
    }

    private func meetLinkChip(meet: Meet?, label: String) -> some View {
        let isSelected = selectedMeetID == meet?.id || (meet == nil && selectedMeetID == nil)
        return Group {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color("EmpireMint") : .white.opacity(0.8))
                    .lineLimit(1)
                if let meet {
                    Text("\(meet.city) · \(meet.dateString)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                } else {
                    Text("Post without event")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
            }
            .frame(width: 132, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color("EmpireMint").opacity(0.14) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color("EmpireMint").opacity(0.45) : Color.white.opacity(0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedMeetID = meet?.id
            }
        }
    }

    private func loadUpcomingMeets() {
        guard !isLoadingMeets else { return }
        isLoadingMeets = true
        Task {
            let meets = (try? await meetsService.fetchUpcomingMeets()) ?? []
            await MainActor.run {
                upcomingMeets = meets
                isLoadingMeets = false
            }
        }
    }
}

// MARK: - Vehicle row

private struct ShareVehicleRow: View {
    let car: Car
    let isSelected: Bool
    var overridePhotoData: Data?

    private var subtitle: String {
        let make  = (car.make  ?? "").trimmingCharacters(in: .whitespaces)
        let model = (car.model ?? "").trimmingCharacters(in: .whitespaces)
        let combined = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? car.description : combined
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let data = overridePhotoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else if let fileName = car.photoFileName,
                          let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                          let data = try? Data(contentsOf: dir.appendingPathComponent(fileName)),
                          let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Image(car.imageName).resizable().scaledToFill()
                }
            }
            .frame(width: 72, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color("EmpireMint").opacity(0.8) : Color.white.opacity(0.15),
                        lineWidth: isSelected ? 1.5 : 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(car.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                ShareStatChip(label: StageSystem.displayLabel(for: car.stage, isJailbreak: car.isJailbreak), tint: StageSystem.accentColor(for: car.stage, isJailbreak: car.isJailbreak))
                ShareStatChip(label: "\(car.horsepower) WHP", tint: .cyan)
            }

            ZStack {
                Circle().stroke(isSelected ? Color("EmpireMint") : Color.white.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                if isSelected {
                    Circle().fill(Color("EmpireMint")).frame(width: 12, height: 12)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? Color("EmpireMint").opacity(0.08) : Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isSelected
                    ? LinearGradient(colors: [Color("EmpireMint").opacity(0.6), Color("EmpireMint").opacity(0.2)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isSelected ? 1.5 : 1))
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Stat chip

private struct ShareStatChip: View {
    let label: String
    let tint: Color
    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded)).fixedSize()
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(tint.opacity(0.6), lineWidth: 1))
            .foregroundStyle(.white)
    }
}

private enum FeedCaptionPrompt: CaseIterable {
    case update
    case goal
    case advice
    case detail

    var title: String {
        switch self {
        case .update: return "What's New"
        case .goal: return "Build Goal"
        case .advice: return "Ask Drivers"
        case .detail: return "Why This Setup"
        }
    }

    var icon: String {
        switch self {
        case .update: return "sparkles"
        case .goal: return "target"
        case .advice: return "bubble.left.and.bubble.right"
        case .detail: return "wrench.and.screwdriver"
        }
    }

    var tint: Color {
        switch self {
        case .update: return Color("EmpireMint")
        case .goal: return .cyan
        case .advice: return Color(red: 1.0, green: 0.52, blue: 0.22)
        case .detail: return Color(red: 0.92, green: 0.24, blue: 0.32)
        }
    }

    var placeholder: String {
        switch self {
        case .update: return "What changed since the last version of this build?"
        case .goal: return "What are you building this car toward?"
        case .advice: return "Ask the community for ideas, feedback, or the next move."
        case .detail: return "Why did you pick this setup, tune, or style direction?"
        }
    }

    var editorHint: String {
        switch self {
        case .update: return "Best when you're sharing a fresh mod, tune, or before-and-after change."
        case .goal: return "Good for giving the post a direction instead of just listing specs."
        case .advice: return "This one works best if you leave the community something to react to."
        case .detail: return "Use this when the story is in the decision behind the setup."
        }
    }

    func seedText(for buildName: String) -> String {
        switch self {
        case .update:
            return "Latest update on \(buildName): "
        case .goal:
            return "The goal with \(buildName) is "
        case .advice:
            return "Need opinions on \(buildName) before I make the next move: "
        case .detail:
            return "Went with this setup on \(buildName) because "
        }
    }
}

// MARK: - Glass card modifier

private extension View {
    func glassCard() -> some View {
        self
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                .blendMode(.screen))
            .shadow(color: Color("EmpireMint").opacity(0.2), radius: 12, y: 6)
    }
}
