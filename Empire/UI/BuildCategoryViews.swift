import SwiftUI

struct BuildCategoryBadge: View {
    let category: BuildCategory
    var size: CGFloat = 24
    var materialOpacity: Double = 0.18
    var strokeOpacity: Double = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.22))
                .background(
                    Circle()
                        .fill(category.tint.opacity(materialOpacity))
                )

            Image(systemName: category.symbolName)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(category.tint)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(category.tint.opacity(strokeOpacity), lineWidth: 1)
        )
        .shadow(color: category.tint.opacity(0.25), radius: 8, x: 0, y: 3)
        .accessibilityLabel(Text(category.title))
    }
}

struct BuildCategoryOptionCard: View {
    let title: String
    let subtitle: String
    let category: BuildCategory?
    let isSelected: Bool
    var isEnabled: Bool = true
    var disabledReason: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((category?.tint ?? .white).opacity(isSelected ? 0.2 : 0.08))
                    .frame(width: 42, height: 42)

                if let category {
                    Image(systemName: category.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(category.tint)
                        .symbolRenderingMode(.hierarchical)
                } else {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isEnabled ? .white : .white.opacity(0.45))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isEnabled ? .white.opacity(0.66) : .white.opacity(0.36))
                    .fixedSize(horizontal: false, vertical: true)

                if let disabledReason, !isEnabled {
                    Text(disabledReason)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 10)

            Image(systemName: isEnabled ? (isSelected ? "checkmark.circle.fill" : "circle") : "lock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    isEnabled
                        ? (isSelected ? (category?.tint ?? Color("EmpireMint")) : .white.opacity(0.28))
                        : .white.opacity(0.32)
                )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke((category?.tint ?? Color("EmpireMint")).opacity(isSelected ? 0.75 : (isEnabled ? 0.18 : 0.08)), lineWidth: 1)
        )
        .opacity(isEnabled ? 1.0 : 0.72)
    }
}
