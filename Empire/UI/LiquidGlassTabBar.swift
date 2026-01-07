import SwiftUI

struct LiquidGlassTabBar: View {
    @Binding var selectedTab: EmpireTab
    @State private var dragLocation: CGFloat? = nil
    @Namespace private var animation

    private let tabWidth: CGFloat = 40
    private let tabSpacing: CGFloat = 22
    private let pillHeight: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let totalWidth = CGFloat(EmpireTab.allCases.count) * tabWidth + CGFloat(EmpireTab.allCases.count - 1) * tabSpacing
            let startX = (geo.size.width - totalWidth) / 2

            ZStack {
                // Pill
                ZStack {
                    RoundedRectangle(cornerRadius: pillHeight/2, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: pillHeight/2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.clear, Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                    RoundedRectangle(cornerRadius: pillHeight/2, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    RoundedRectangle(cornerRadius: pillHeight/2, style: .continuous)
                        .fill(
                            LinearGradient(colors: [Color.white.opacity(0.15), Color.clear],
                                           startPoint: .top,
                                           endPoint: .center)
                        )
                        .mask(RoundedRectangle(cornerRadius: pillHeight/2))
                }
                .frame(width: totalWidth + 24, height: pillHeight)
                .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
                .position(x: geo.size.width/2, y: geo.size.height/2)

                // Tabs
                HStack(spacing: tabSpacing) {
                    ForEach(Array(EmpireTab.allCases.enumerated()), id: \.offset) { index, tab in
                        ZStack {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: pillHeight/2)
                                    .fill(.ultraThinMaterial)
                                    .frame(width: tabWidth + 12, height: tabWidth + 12)
                                    .matchedGeometryEffect(id: "activeTab", in: animation)
                                    .shadow(color: Color("EmpireMint").opacity(0.25), radius: 12)
                                    .transition(.opacity.combined(with: .scale))
                            }
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(selectedTab == tab ? Color("EmpireMint") : Color.white.opacity(0.55))
                                .shadow(color: selectedTab == tab ? Color("EmpireMint").opacity(0.85) : .clear, radius: 8)
                                .scaleEffect(selectedTab == tab ? 1.15 : 1.0)
                                .offset(y: selectedTab == tab ? -3 : 0)
                                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.75), value: selectedTab)
                                .frame(width: tabWidth, height: tabWidth)
                        }
                    }
                }
                .frame(width: totalWidth, height: pillHeight)
                .position(x: geo.size.width/2, y: geo.size.height/2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragLocation = value.location.x
                            updateTab(from: dragLocation ?? value.location.x, geo: geo)
                        }
                        .onEnded { _ in
                            dragLocation = nil
                        }
                )
            }
            .frame(height: pillHeight)
        }
        .frame(height: pillHeight)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func updateTab(from locationX: CGFloat, geo: GeometryProxy) {
        let totalWidth = CGFloat(EmpireTab.allCases.count) * tabWidth + CGFloat(EmpireTab.allCases.count - 1) * tabSpacing
        let startX = (geo.size.width - totalWidth) / 2
        let relativeX = locationX - startX
        let index = max(0, min(EmpireTab.allCases.count - 1, Int((relativeX / (tabWidth + tabSpacing)).rounded())))
        selectedTab = EmpireTab.allCases[index]
    }
}
