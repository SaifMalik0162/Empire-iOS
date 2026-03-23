import SwiftUI
import PhotosUI

struct ShareToFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    let userCars: [Car]
    var onPosted: ((CommunityPost) -> Void)?

    @StateObject private var communityVM = CommunityViewModel()

    @State private var selectedCarIndex: Int = 0
    @State private var caption: String = ""
    @State private var isPosting = false
    @State private var errorMessage: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var overridePhotoData: Data? = nil

    private var selectedCar: Car? { userCars[safe: selectedCarIndex] }

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
                            // 1 — Vehicle list picker
                            carPickerSection
                            // 2 — Override photo
                            photoOverrideSection
                            // 3 — Caption
                            captionSection
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.9))
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
                    Button("Cancel") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: sharePost) {
                        if isPosting {
                            ProgressView().tint(Color("EmpireMint")).scaleEffect(0.85)
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("EmpireMint"))
                        }
                    }
                    .disabled(isPosting || selectedCar == nil)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { overridePhotoData = data }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - No cars

    private var noCarsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "car.fill")
                .font(.system(size: 42))
                .foregroundStyle(Color("EmpireMint").opacity(0.5))
            Text("No vehicles in your garage")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Add a car to your garage first, then you can share it to the community feed.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .glassCard()
    }

    // MARK: - Car picker

    private var carPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Select vehicle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("EmpireMint"))
                Spacer()
                Text("\(selectedCarIndex + 1) of \(userCars.count)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            // Cap at ~2.5 rows so it never grows infinitely; scroll within the card
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(userCars.indices, id: \.self) { idx in
                        ShareVehicleRow(
                            car: userCars[idx],
                            isSelected: idx == selectedCarIndex,
                            overridePhotoData: idx == selectedCarIndex ? overridePhotoData : nil
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

            // Hint that there are more rows to scroll
            if userCars.count > 2 {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color("EmpireMint").opacity(0.5))
                    Text("Scroll to see all vehicles")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .glassCard()
    }

    // MARK: - Photo override

    private var photoOverrideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Override photo")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("EmpireMint"))

            HStack(spacing: 12) {
                // Preview thumbnail
                Group {
                    if let data = overridePhotoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("EmpireMint").opacity(0.5), lineWidth: 1.5))
                    } else if let car = selectedCar,
                              let fileName = car.photoFileName,
                              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                              let data = try? Data(contentsOf: dir.appendingPathComponent(fileName)),
                              let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 72, height: 54)
                            Image(systemName: "photo")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text(overridePhotoData == nil ? "Choose different photo" : "Change photo")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        )
                    }

                    if overridePhotoData != nil {
                        Button {
                            overridePhotoData = nil
                            selectedPhotoItem = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 11))
                                Text("Use car's saved photo")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }

            Text("Leave empty to automatically use the photo from your garage.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .glassCard()
    }

    // MARK: - Caption

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Caption")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("EmpireMint"))

            ZStack(alignment: .topLeading) {
                if caption.isEmpty {
                    Text("Add a caption… (optional)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 10)
                        .padding(.leading, 14)
                }
                TextEditor(text: $caption)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .foregroundStyle(.white)
                    .font(.subheadline)
                    .frame(minHeight: 80, maxHeight: 160)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )

            Text("\(caption.count)/280")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .glassCard()
        .onChange(of: caption) { _, new in
            if new.count > 280 { caption = String(new.prefix(280)) }
        }
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
                    caption: caption.isEmpty ? nil : caption,
                    photoData: overridePhotoData ?? loadCarPhotoData(for: car)
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

    private func loadCarPhotoData(for car: Car) -> Data? {
        guard let fileName = car.photoFileName,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return try? Data(contentsOf: dir.appendingPathComponent(fileName))
    }
}

// MARK: - Vehicle row (ManageGarageSheet style)

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
            // Thumbnail
            Group {
                if let data = overridePhotoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else if let fileName = car.photoFileName,
                          let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                          let data = try? Data(contentsOf: dir.appendingPathComponent(fileName)),
                          let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(car.imageName)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 72, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color("EmpireMint").opacity(0.8) : Color.white.opacity(0.15),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )

            // Name + make/model — given all remaining space
            VStack(alignment: .leading, spacing: 4) {
                Text(car.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                if car.isJailbreak {
                    ShareStatChip(label: "Jailbreak", tint: .purple)
                } else if car.stage == 0 {
                    ShareStatChip(label: "Stock", tint: .gray)
                } else {
                    ShareStatChip(label: "Stage \(car.stage)", tint: stageTint(for: car.stage))
                }
                ShareStatChip(label: "\(car.horsepower) HP", tint: .cyan)
            }

            // Radio button
            ZStack {
                Circle()
                    .stroke(isSelected ? Color("EmpireMint") : Color.white.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                if isSelected {
                    Circle()
                        .fill(Color("EmpireMint"))
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color("EmpireMint").opacity(0.08) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected
                        ? LinearGradient(colors: [Color("EmpireMint").opacity(0.6), Color("EmpireMint").opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Stat chip

private struct ShareStatChip: View {
    let label: String
    let tint: Color
    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(tint.opacity(0.6), lineWidth: 1))
            .foregroundStyle(.white)
    }
}

private func stageTint(for stage: Int) -> Color {
    switch stage {
    case 1: return Color("EmpireMint")
    case 2: return .yellow
    case 3: return .red
    default: return .gray
    }
}

// MARK: - Glass card modifier

private extension View {
    func glassCard() -> some View {
        self
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .blendMode(.screen)
            )
            .shadow(color: Color("EmpireMint").opacity(0.2), radius: 12, y: 6)
    }
}
