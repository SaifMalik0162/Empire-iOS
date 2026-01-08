import SwiftUI

struct MeetsView: View {
    let meets: [Meet]
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 100)

                    ForEach(meets) { meet in
                        LiquidGlassMeetCard(meet: meet)
                            .padding(.horizontal, 18)
                            .shadow(color: Color("EmpireMint").opacity(0.25), radius: 20, x: 0, y: 14)
                            .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 6)
                            .modifier(Parallax(y: scrollOffset, strength: 18))
                    }

                    Spacer(minLength: 80)
                }
                .background(
                    GeometryReader { geo in
                        Rectangle().fill(.clear)
                            .preference(key: OffsetKey.self, value: -geo.frame(in: .named("scroll")).minY)
                    }
                )
                .onPreferenceChange(OffsetKey.self) { value in
                    scrollOffset = value
                }
            }
            .coordinateSpace(name: "scroll")
            .background(
                ZStack {
                    // Layered dynamic blobs for depth
                    Blob(color: Color("EmpireMint").opacity(0.25), size: size, x: 0.2, y: 0.1, blur: 120)
                    Blob(color: Color.cyan.opacity(0.18), size: size, x: 0.85, y: 0.05, blur: 140)
                    Blob(color: Color.purple.opacity(0.12), size: size, x: 0.15, y: 0.9, blur: 180)

                    LinearGradient(
                        colors: [Color.black, Color.black.opacity(0.96), Color.black.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    // Subtle glass overlay noise
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.35)
                        .blendMode(.plusLighter)
                        .ignoresSafeArea()
                }
            )
        }
    }
}

private struct OffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - LiquidGlassMeetCard
private struct LiquidGlassMeetCard: View {
    let meet: Meet
    @State private var isPressed = false
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Base glass
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    // Inner glow + refraction highlight
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.35),
                                    Color("EmpireMint").opacity(0.6),
                                    .clear,
                                    Color.white.opacity(0.2)
                                ]),
                                center: .center
                            ), lineWidth: 1.0
                        )
                        .blendMode(.screen)
                        .opacity(0.9)
                )
                .background(
                    // Edge specular highlight
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1
                        )
                        .blur(radius: 0.5)
                        .opacity(0.7)
                )
                .overlay(
                    // Animated shimmer sweep
                    ShimmerMask()
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .opacity(0.7)
                        .blendMode(.screen)
                )
                .shadow(color: Color("EmpireMint").opacity(0.18), radius: 25, x: 0, y: 16)
                .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 8)

            // Card content
            HStack(spacing: 14) {
                // Accent glass orb
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(colors: [Color("EmpireMint").opacity(0.9), .clear], center: .center, startRadius: 2, endRadius: 36)
                        )
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle()
                                .stroke(LinearGradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                        )
                        .shadow(color: Color("EmpireMint").opacity(0.4), radius: 10, x: 0, y: 6)

                    Circle()
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                        .blur(radius: 2)
                        .frame(width: 54, height: 54)
                        .blendMode(.plusLighter)
                }
                .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(meet.title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: Color("EmpireMint").opacity(0.7), radius: 2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .imageScale(.small)
                            .foregroundStyle(Color("EmpireMint"))
                            .opacity(0.9)
                        Text("\(meet.city) · \(meet.dateString)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("EmpireMint"))
                    .shadow(color: Color("EmpireMint").opacity(0.6), radius: 2)
                    .padding(.trailing, 4)
            }
            .padding(20)
        }
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .blur(radius: 10)
                .opacity(0.7)
        )
        .overlay(
            // Soft caustics
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(colors: [Color("EmpireMint").opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2
                )
                .blendMode(.plusLighter)
                .opacity(0.8)
        )
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isPressed = false
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }
}

// MARK: - Effects
private struct ShimmerMask: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color.white.opacity(0.35), location: 0.45),
                    .init(color: .clear, location: 0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: width)
            .offset(x: -width + phase * (width * 2))
            .onAppear {
                withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Parallax: ViewModifier {
    let y: CGFloat
    let strength: CGFloat

    func body(content: Content) -> some View {
        let offset = (y / 200).clamped(to: -1...1) * strength
        content.offset(y: offset)
    }
}

private extension Comparable where Self: Strideable, Self.Stride: SignedNumeric {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private struct Blob: View {
    let color: Color
    let size: CGSize
    let x: CGFloat
    let y: CGFloat
    let blur: CGFloat

    var body: some View {
        let w = size.width
        let h = size.height
        Circle()
            .fill(color)
            .frame(width: max(w, h) * 0.8)
            .position(x: w * x, y: h * y)
            .blur(radius: blur)
            .blendMode(.plusLighter)
            .ignoresSafeArea()
    }
}

// MARK: - Preview
struct MeetsView_Previews: PreviewProvider {
    static var previews: some View {
        MeetsView(meets: [
            Meet(title: "Winter Cruise", city: "Toronto", date: Date()),
            Meet(title: "Stage 2 Meetup", city: "Vancouver", date: Date().addingTimeInterval(86400 * 5)),
            Meet(title: "Track Day", city: "Montreal", date: Date().addingTimeInterval(86400 * 10))
        ])
        .preferredColorScheme(.dark)
    }
}
