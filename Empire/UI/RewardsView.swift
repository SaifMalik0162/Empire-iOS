import SwiftUI

struct RewardsView: View {
    @Environment(\.dismiss) private var dismiss

    // Placeholder state to simulate backend wiring later
    @State private var currentPoints: Int = 1240
    @State private var isVIP: Bool = false // Flip true to preview VIP doubling banner

    // Tier thresholds (inclusive lower bounds)
    private let tiers: [(name: String, threshold: Int)] = [
        ("Member", 0),
        ("Silver", 1000),
        ("Gold", 2000),
        ("Platinum", 5000)
    ]

    private var currentTier: String {
        tiers.last(where: { currentPoints >= $0.threshold })?.name ?? tiers.first!.name
    }

    private var nextTierInfo: (name: String, threshold: Int)? {
        guard let idx = tiers.firstIndex(where: { $0.name == currentTier }) else { return nil }
        let nextIdx = idx + 1
        return nextIdx < tiers.count ? tiers[nextIdx] : nil
    }

    private var nextTier: String {
        nextTierInfo?.name ?? currentTier
    }

    private var nextTierThreshold: Int {
        nextTierInfo?.threshold ?? max(currentPoints, tiers.last!.threshold)
    }

    private var progressToNextTier: Double {
        guard let next = nextTierInfo else { return 1.0 }
        let lower = tiers.last(where: { $0.threshold <= currentPoints })?.threshold ?? 0
        let span = max(next.threshold - lower, 1)
        let progress = Double(currentPoints - lower) / Double(span)
        return min(max(progress, 0), 1)
    }

    private var recentActivity: [(String, Int, String)] {
        // (title, points, date)
        [
            ("Merch purchase", 120, "Today"),
            ("Show check-in", 80, "2d ago"),
            ("Invite a friend", 200, "5d ago")
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 320)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // Header card with points & progress
                    ZStack {
                        glassCard(cornerRadius: 28)

                        VStack(spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: "gift.fill")
                                    .foregroundStyle(Color("EmpireMint"))
                                    .font(.system(size: 20, weight: .bold))
                                Text("Empire Rewards")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Tier: \(currentTier)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(.ultraThinMaterial))
                                    .overlay(Capsule().stroke(gradientStroke, lineWidth: 1))
                            }

                            // Points + Progress
                            HStack(spacing: 16) {
                                PointsRing(points: currentPoints, color: Color("EmpireMint"))
                                    .frame(width: 96, height: 96)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(currentPoints) points")
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)
                                    ProgressView(value: progressToNextTier)
                                        .tint(Color("EmpireMint"))
                                        .background(
                                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                                                .frame(height: 6)
                                        )
                                    HStack {
                                        Text("Next: \(nextTier)")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.75))
                                        Spacer()
                                        Text("\(currentPoints)/\(nextTierThreshold)")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                            }

                            // VIP banner
                            HStack(spacing: 10) {
                                Image(systemName: "crown.fill").foregroundStyle(Color("EmpireMint"))
                                Text(isVIP ? "VIP active: You earn 2× points on eligible actions" : "Join VIP to earn 2× points on eligible actions")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(gradientStroke, lineWidth: 1))
                        }
                        .padding(18)
                    }
                    .padding(.horizontal, 16)

                    // Milestones / tiers
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Milestones")
                            .font(.headline)
                            .foregroundStyle(.white)

                        VStack(spacing: 10) {
                            milestoneRow(title: "Member", threshold: 0, achieved: currentPoints >= 0)
                            milestoneRow(title: "Silver", threshold: 1000, achieved: currentPoints >= 1000)
                            milestoneRow(title: "Gold", threshold: 2000, achieved: currentPoints >= 2000)
                            milestoneRow(title: "Platinum", threshold: 5000, achieved: currentPoints >= 5000)
                        }
                    }
                    .padding(16)
                    .background(glassCard(cornerRadius: 22))
                    .padding(.horizontal, 16)

                    // Recent activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(Array(recentActivity.enumerated()), id: \.offset) { _, item in
                            activityRow(title: item.0, points: item.1, date: item.2)
                        }
                    }
                    .padding(16)
                    .background(glassCard(cornerRadius: 22))
                    .padding(.horizontal, 16)

                    Text("Rewards system is a work in progress. Values shown here are for preview only.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                .padding(.top, 16)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 60)
                }
            }
        }
        .navigationTitle("Rewards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews & helpers

    private var gradientStroke: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func glassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(gradientStroke, lineWidth: 1)
                    .blendMode(.screen)
            )
            .shadow(color: Color("EmpireMint").opacity(0.2), radius: 12, y: 6)
    }

    private func milestoneRow(title: String, threshold: Int, achieved: Bool) -> some View {
        // Tier symbol + gradient color mapping
        let (symbol, gradient): (String, LinearGradient) = {
            switch title {
            case "Member":
                return ("seal.fill", LinearGradient(colors: [Color("EmpireMint"), Color("EmpireMint").opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
            case "Silver":
                return ("hexagon.fill", LinearGradient(colors: [Color(white: 0.85), Color(white: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
            case "Gold":
                return ("diamond.fill", LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
            case "Platinum":
                return ("star.circle.fill", LinearGradient(colors: [Color.cyan, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
            default:
                return ("seal", LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }()

        // Standardized badge size
        let badgeSize: CGFloat = 28

        return HStack(spacing: 12) {
            ZStack {
                if achieved {
                    Circle()
                        .fill(gradient)
                        .opacity(0.18)
                        .blur(radius: 6)
                }
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: badgeSize, height: badgeSize)
                    .overlay(
                        Circle().stroke(gradientStroke, lineWidth: 1)
                    )
                    .overlay(
                        gradient
                            .mask(
                                Image(systemName: symbol)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(6)
                            )
                    )
            }
            .frame(width: badgeSize, height: badgeSize)
            .shadow(color: achieved ? Color.black.opacity(0.25) : .clear, radius: achieved ? 6 : 0, y: achieved ? 3 : 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white)
                    .font(.subheadline.weight(.semibold))
                Text("\(threshold) pts")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()

            let chipGradient = achieved ? gradient : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(achieved ? "Unlocked" : "Locked")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(chipGradient)
                )
                .overlay(
                    Capsule().stroke(gradientStroke, lineWidth: 1)
                )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(gradientStroke, lineWidth: 1)
        )
    }

    private func activityRow(title: String, points: Int, date: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color("EmpireMint"))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white)
                    .font(.subheadline.weight(.semibold))
                Text(date)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Text("+\(points)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .overlay(Capsule().stroke(gradientStroke, lineWidth: 1))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(gradientStroke, lineWidth: 1))
    }
}

private struct PointsRing: View {
    let points: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(CGFloat(points % 1000) / 1000.0, 1))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("PTS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(points)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    RewardsView()
}

