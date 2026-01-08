import SwiftUI

struct ExpandedCarView: View {
    let car: Car
    @Namespace private var ns

    var body: some View {
        CarExpandedCard(car: car, ns: ns) {}
    }
}

struct CarExpandedCard: View {
    let car: Car
    var ns: Namespace.ID
    var onClose: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .blendMode(.screen)
                )
                .overlay(HoloShimmerMask().clipShape(RoundedRectangle(cornerRadius: 28)))
                .shadow(color: Color("EmpireMint").opacity(0.22), radius: 28, x: 0, y: 18)
                .matchedGeometryEffect(id: "card-\(car.id)", in: ns)

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color("EmpireMint").opacity(0.5), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                                .blendMode(.plusLighter)
                        )
                        .matchedGeometryEffect(id: "imageBG-\(car.id)", in: ns)

                    Image(car.imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .matchedGeometryEffect(id: "image-\(car.id)", in: ns)
                }
                .frame(height: 200)

                VStack(spacing: 6) {
                    Text(car.name)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .matchedGeometryEffect(id: "title-\(car.id)", in: ns)

                    Text(car.description)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                VStack(spacing: 10) {
                    StatRow(name: "Horsepower", value: Double(car.horsepower), max: 1200, accent: Color("EmpireMint"))
                    StatRow(name: "Stage", value: Double(car.stage), max: 5, accent: .purple)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )

                HStack(spacing: 12) {
                    GlassButton(title: "Mods")
                    GlassButton(title: "Specs")
                    GlassButton(title: "Share")
                }
                .padding(.top, 2)

                GlassButton(title: "Close") {
                    onClose()
                }
                .padding(.top, 6)
            }
            .padding(20)
        }
    }
}

private struct StatRow: View {
    let name: String
    let value: Double
    let max: Double
    let accent: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(displayValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.9), accent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: barWidth)
                    .shadow(color: accent.opacity(0.4), radius: 6, x: 0, y: 2)
            }
            .frame(height: 10)
        }
    }

    private var normalized: Double { max == 0 ? 0 : min(value / max, 1) }
    private var barWidth: CGFloat { CGFloat(normalized) * 220 }
    private var displayValue: String {
        if name == "Stage" { return "\(Int(value))" }
        if name == "Horsepower" { return "\(Int(value)) HP" }
        return String(format: "%.0f", value)
    }
}

private struct GlassButton: View {
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule().stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color("EmpireMint").opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

private struct HoloShimmerMask: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white.opacity(0.3), location: 0.45),
                .init(color: .clear, location: 0.9)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .scaleEffect(x: 1.8)
        .offset(x: -120 + phase * 240)
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .blendMode(.screen)
        .opacity(0.6)
        .allowsHitTesting(false)
    }
}

struct ExpandedCarView_Previews: PreviewProvider {
    static var previews: some View {
        ExpandedCarView(car: Car(name: "Preview Car", description: "Stage 2 - Tuned", imageName: "car1", horsepower: 420, stage: 2))
            .preferredColorScheme(.dark)
    }
}
