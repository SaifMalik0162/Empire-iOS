import SwiftUI

struct CarsView: View {
    // MARK: - User's cars
    @State private var cars: [Car] = [
        Car(name: "Honda Accord", description: "Stage 1 - Luh RS7", imageName: "car0", horsepower: 240, stage: 1)
    ]

    // MARK: - Community Cars
    @State private var communityCars: [Car] = [
        Car(name: "Nissan GT-R", description: "Stage 2 - Track Edition", imageName: "car3", horsepower: 550, stage: 2),
        Car(name: "BMW M3", description: "Stage 3 - Turbo", imageName: "car1", horsepower: 420, stage: 3),
        Car(name: "Audi RS7", description: "Stage 1 - Full Tune", imageName: "car2", horsepower: 620, stage: 1)
    ]

    @State private var selectedCarIndex: Int? = nil
    @Namespace private var ns
    @State private var ripple: Bool = false

    var body: some View {
        ZStack {
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    userCarousel
                    communitySection
                }
                .padding(.vertical, 12)
            }

            // Expanded card overlays above
            if let selected = selectedCarIndex, cars.indices.contains(selected) {
                // Dim background
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            selectedCarIndex = nil
                        }
                    }

                CarExpandedCardInline(car: cars[selected], ns: ns) {
                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        selectedCarIndex = nil
                    }
                }
                .zIndex(1)
                .frame(maxWidth: 480)
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            }

            CoolRipple(active: $ripple)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

// MARK: - Sections
private extension CarsView {
    var background: some View {
        LinearGradient(colors: [Color.black, Color.black.opacity(0.95)],
                       startPoint: .top,
                       endPoint: .bottom)
            .ignoresSafeArea()
    }

    var userCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(cars.indices, id: \.self) { idx in
                    LiquidGlassCarCard(car: cars[idx], ns: ns)
                        .frame(width: selectedCarIndex == idx ? 300 : 220,
                               height: selectedCarIndex == idx ? 380 : 250)
                        .scaleEffect(selectedCarIndex == idx ? 1.04 : 1)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                selectedCarIndex = selectedCarIndex == idx ? nil : idx
                                ripple = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                ripple = false
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 360)
    }

    var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Community Gallery")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("See All")
                    .font(.caption)
                    .foregroundColor(Color("EmpireMint").opacity(0.9))
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 12)
            ], spacing: 12) {
                ForEach(communityCars.indices, id: \.self) { idx in
                    GalleryTile(car: communityCars[idx])
                        .onTapGesture {
                            // future: open detail/lightbox
                            selectedCarIndex = nil
                        }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Liquid Glass Compact Card
private struct LiquidGlassCarCard: View {
    let car: Car
    var ns: Namespace.ID

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        .blendMode(.screen)
                )
                .shadow(color: Color("EmpireMint").opacity(0.18), radius: 18, x: 0, y: 10)
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)
                .matchedGeometryEffect(id: "card-\(car.id)", in: ns)

            // Full-bleed background image
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Image(car.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .opacity(0.55)
                        .matchedGeometryEffect(id: "image-\(car.id)", in: ns)
                        .clipped()

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.22), location: 0.48),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    .opacity(0.28)
                    .blur(radius: 10)
                    .rotationEffect(.degrees(18))
                    .modifier(CompactShineAnimation(cardCorner: 22))

                }
                .mask(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                
            }

            // Foreground overlay
            VStack(alignment: .leading, spacing: 8) {
                Spacer(minLength: 0)

                Text(car.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.white)
                    .matchedGeometryEffect(id: "title-\(car.id)", in: ns)

                VStack(alignment: .leading, spacing: 6) {
                    StatCapsule(label: "Stage", value: "\(car.stage)", tint: Color("EmpireMint"))
                    StatCapsule(label: "HP", value: "\(car.horsepower)", tint: .cyan)
                }
            }
            .padding(14)
        }
    }
}

private struct CompactShineAnimation: ViewModifier {
    @State private var phase: CGFloat = -1.1
    let cardCorner: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: phase * 220, y: phase * 80)
            .onAppear {
                phase = -1.1
                withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
            .onDisappear {
                // Reset so it restarts when the view reappears
                phase = -1.1
            }
            .allowsHitTesting(false)
            .clipped()
    }
}

private struct StatCapsule: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
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
                    Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
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

private struct GalleryTile: View {
    let car: Car
    @State private var liked: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image-first tile
            ZStack(alignment: .bottomLeading) {
                Image(car.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    )

                // Minimal metadata badges
                HStack(spacing: 8) {
                    StatCapsule(label: "Stage", value: "\(car.stage)", tint: Color("EmpireMint"))
                    StatCapsule(label: "HP", value: "\(car.horsepower)", tint: .cyan)
                }
                .padding(10)
            }

            // Like button
            Button(action: { liked.toggle() }) {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .foregroundStyle(liked ? Color("EmpireMint") : .white)
                    .padding(8)
                    .background(
                        Circle().fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(10)
        }
    }
}

// MARK: - Expanded Card (Pokemon-style)
private struct CarExpandedCardInline: View {
    let car: Car
    var ns: Namespace.ID
    var onClose: () -> Void

    var body: some View {
        ZStack {
            // Card base with glass and shimmer
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .blendMode(.screen)
                )
                .overlay(HoloShimmerMask().clipShape(RoundedRectangle(cornerRadius: 28)))
                .shadow(color: Color("EmpireMint").opacity(0.22), radius: 28, x: 0, y: 18)
                .matchedGeometryEffect(id: "card-\(car.id)", in: ns)

            // embedded full-card image (faint, fully clipped with mask)
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Image(car.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .opacity(0.5)
                        .matchedGeometryEffect(id: "image-\(car.id)", in: ns)
                        .accessibilityHidden(true)
                        .clipped()

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.12),
                            Color.black.opacity(0.32)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .mask(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .allowsHitTesting(false)
            }

            // Foreground content
            VStack(spacing: 16) {
                // Title & subtitle
                VStack(spacing: 6) {
                    Text(car.name)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)
                        .matchedGeometryEffect(id: "title-\(car.id)", in: ns)

                    Text(car.description)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 8)

                // Compact badges
                HStack(spacing: 10) {
                    StatCapsule(label: "Stage", value: "\(car.stage)", tint: Color("EmpireMint"))
                    StatCapsule(label: "HP", value: "\(car.horsepower)", tint: .cyan)
                }

                // Stat meters positioned higher on the card
                VStack(spacing: 10) {
                    StatRow(name: "Horsepower", value: Double(car.horsepower), max: 700, accent: Color("EmpireMint"))
                    StatRow(name: "Stage", value: Double(car.stage), max: 3, accent: .purple)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )

                // Spacer pushes buttons to the bottom area of the card
                Spacer(minLength: 6)

                // Action buttons lowered
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        GlassButton(title: "Mods") { hapticTap() }
                        GlassButton(title: "Specs") { hapticTap() }
                        GlassButton(title: "Share") { hapticTap() }
                    }

                    GlassButton(title: "Close") {
                        onClose()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Reusable Components
private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color.opacity(0.18))
            )
            .overlay(
                Capsule().stroke(color.opacity(0.6), lineWidth: 1)
            )
            .foregroundStyle(.white)
    }
}

private struct StatRow: View {
    let name: String
    let value: Double
    let max: Double
    let accent: Color

    @State private var animate: Bool = false

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
                    .fill(LinearGradient(colors: [accent.opacity(0.9), accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: animate ? barWidth : 0)
                    .shadow(color: accent.opacity(0.4), radius: 6, x: 0, y: 2)
            }
            .frame(height: 10)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    animate = true
                }
            }
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

private func hapticTap() {
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
}

// MARK: - Preview
struct CarsView_Previews: PreviewProvider {
    static var previews: some View {
        CarsView()
            .preferredColorScheme(.dark)
    }
}
