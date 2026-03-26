import SwiftUI

struct CarCardView: View {
    let car: Car
    let isExpanded: Bool
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Car card image
            Image(car.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: isExpanded ? 300 : 200,
                       height: isExpanded ? 380 : 250)
                .clipped()
                .cornerRadius(28)
            
            // Faded gradient overlay
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .cornerRadius(28)
            
            // description in carousel
            VStack(alignment: .leading, spacing: 4) {
                Text(car.name)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                
                Text(car.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(16)
            
            HStack(spacing: 8) {
                StatCapsule(label: StageSystem.displayLabel(for: car.stage, isJailbreak: car.isJailbreak), value: "", tint: StageSystem.accentColor(for: car.stage, isJailbreak: car.isJailbreak))
                StatCapsule(label: "WHP", value: "\(car.horsepower)", tint: .cyan)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 6)
        .highPriorityGesture(TapGesture(count: 2).onEnded { /* no-op for now; parent can intercept */ })
    }
}

private struct StatCapsule: View {
    let label: String
    let value: String
    let tint: Color

    private var hasValue: Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        Group {
            if hasValue {
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
            } else {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(tint.opacity(0.9))
            }
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
