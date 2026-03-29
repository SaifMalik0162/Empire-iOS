import SwiftUI

struct RewardsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 320)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header
                perks
                Spacer(minLength: 0)
                cta
                legal
            }
            .padding(24)
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

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color("EmpireMint"))
                .shadow(color: Color("EmpireMint").opacity(0.5), radius: 12, x: 0, y: 6)

            Text("Rewards")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Rewards will launch once Connect+ and the points system are fully ready.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))

            Text("Rewards are planned after the beta.")
                .font(.headline)
                .foregroundStyle(Color("EmpireMint"))
                .padding(.top, 2)
        }
        .padding(.top, 20)
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 14) {
            placeholderRow(icon: "star.circle.fill", title: "Points & Progress", subtitle: "Track points, milestones, and unlocks.")
            placeholderRow(icon: "crown.fill", title: "Connect+ Bonuses", subtitle: "See bonus earning perks tied to membership.")
            placeholderRow(icon: "sparkles", title: "Future Rewards", subtitle: "Redeem points for drops, perks, and extras.")
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }

    private func placeholderRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color("EmpireMint").opacity(0.15))
                Image(systemName: icon)
                    .foregroundStyle(Color("EmpireMint"))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white)
                    .font(.headline)
                Text(subtitle)
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.subheadline)
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    private var cta: some View {
        Button(action: {}) {
            Text("Coming Soon")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("EmpireMint"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.black)
                .shadow(color: Color("EmpireMint").opacity(0.25), radius: 12, x: 0, y: 8)
        }
        .disabled(true)
        .opacity(0.7)
    }

    private var legal: some View {
        Text("Features and availability may vary by release.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.6))
            .multilineTextAlignment(.center)
    }
}

#Preview {
    NavigationStack {
        RewardsView()
    }
}
