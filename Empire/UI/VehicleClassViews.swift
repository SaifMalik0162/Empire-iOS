import SwiftUI

struct VehicleClassBadge: View {
    let vehicleClass: VehicleClass
    var size: CGFloat = 24
    var materialOpacity: Double = 0.18
    var strokeOpacity: Double = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.22))
                .background(
                    Circle()
                        .fill(vehicleClass.accentColor.opacity(materialOpacity))
                )

            Text(vehicleClass.code)
                .font(.system(size: size * 0.46, weight: .black, design: .rounded))
                .foregroundStyle(vehicleClass.accentColor)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(vehicleClass.accentColor.opacity(strokeOpacity), lineWidth: 1)
        )
        .shadow(color: vehicleClass.accentColor.opacity(0.25), radius: 8, x: 0, y: 3)
        .accessibilityLabel(Text("Class \(vehicleClass.code), \(vehicleClass.displayName)"))
    }
}

struct VehicleClassChip: View {
    let vehicleClass: VehicleClass
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 5 : 6) {
            Text(vehicleClass.code)
                .font(.system(size: compact ? 9 : 10, weight: .black, design: .rounded))
            Text(vehicleClass.displayName)
                .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(vehicleClass.accentColor)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 5 : 6)
        .background(Capsule().fill(vehicleClass.accentColor.opacity(0.14)))
        .overlay(Capsule().stroke(vehicleClass.accentColor.opacity(0.65), lineWidth: 1))
    }
}

struct VehicleClassCard: View {
    let vehicleClass: VehicleClass
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vehicleClass.code)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(vehicleClass.accentColor)
                    Text(vehicleClass.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(vehicleClass.accentColor)
                }
            }

            metadataBlock(title: "Definition", value: vehicleClass.factoryDefinition)
            metadataBlock(title: "Includes", value: vehicleClass.includes)
            metadataBlock(title: "Examples", value: vehicleClass.exampleVehicles)
            metadataBlock(title: "Origin", value: vehicleClass.primaryCountries)
        }
        .padding(16)
        .frame(width: 290, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isSelected ? vehicleClass.accentColor.opacity(0.85) : Color.white.opacity(0.14),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(color: vehicleClass.accentColor.opacity(isSelected ? 0.22 : 0.08), radius: 12, x: 0, y: 6)
    }

    private func metadataBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(vehicleClass.accentColor.opacity(0.9))
            Text(value)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
