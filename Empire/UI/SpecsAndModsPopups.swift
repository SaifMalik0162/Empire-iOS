import SwiftUI

// MARK: - Specs Popup

struct SpecsListView: View {
    let specs: [SpecItem]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color("EmpireMint").opacity(0.14), .clear],
                center: .top, startRadius: 10, endRadius: 340
            )
            .ignoresSafeArea()

            if specs.isEmpty {
                popupEmptyState(icon: "gauge", message: "No specs added yet")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        Text("Specs")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 6)

                        ForEach(specs) { spec in
                            SpecRow(spec: spec)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SpecRow: View {
    let spec: SpecItem

    var body: some View {
        HStack(spacing: 14) {
            Text(spec.key.isEmpty ? "—" : spec.key)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("EmpireMint"))
                .frame(width: 110, alignment: .leading)
                .lineLimit(1)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 20)

            Text(spec.value.isEmpty ? "Not set" : spec.value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(spec.value.isEmpty ? .white.opacity(0.3) : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.04)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color("EmpireMint").opacity(0.08), radius: 6, y: 3)
    }
}

// MARK: - Mods Popup

struct ModsListView: View {
    let mods: [ModItem]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color("EmpireMint").opacity(0.14), .clear],
                center: .top, startRadius: 10, endRadius: 340
            )
            .ignoresSafeArea()

            if mods.isEmpty {
                popupEmptyState(icon: "wrench.and.screwdriver", message: "No mods added yet")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        Text("Mods")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 6)

                        let major = mods.filter { $0.isMajor }
                        let minor = mods.filter { !$0.isMajor }

                        if !major.isEmpty {
                            PopupSectionLabel(title: "Major Mods")
                            ForEach(major) { mod in
                                ModRow(mod: mod)
                            }
                        }

                        if !minor.isEmpty {
                            PopupSectionLabel(title: "Other Mods")
                                .padding(.top, major.isEmpty ? 0 : 6)
                            ForEach(minor) { mod in
                                ModRow(mod: mod)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PopupSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color("EmpireMint").opacity(0.7))
            .kerning(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

private struct ModRow: View {
    let mod: ModItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(mod.isMajor ? Color("EmpireMint").opacity(0.15) : Color.white.opacity(0.06))
                    .frame(width: 36, height: 36)

                Image(systemName: mod.isMajor ? "bolt.fill" : "wrench.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(mod.isMajor ? Color("EmpireMint") : .white.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(mod.title.isEmpty ? "Untitled Mod" : mod.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !mod.notes.isEmpty {
                    Text(mod.notes)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
            }

            Spacer()

            if mod.isMajor {
                Text("MAJOR")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color("EmpireMint"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color("EmpireMint").opacity(0.12))
                            .overlay(Capsule().stroke(Color("EmpireMint").opacity(0.4), lineWidth: 0.8))
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    mod.isMajor ? Color("EmpireMint").opacity(0.3) : Color.white.opacity(0.15),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: mod.isMajor ? Color("EmpireMint").opacity(0.1) : .clear, radius: 6, y: 3)
    }
}

// MARK: - Shared empty state

private func popupEmptyState(icon: String, message: String) -> some View {
    VStack(spacing: 14) {
        Image(systemName: icon)
            .font(.system(size: 44))
            .foregroundStyle(Color("EmpireMint").opacity(0.35))
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.45))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
