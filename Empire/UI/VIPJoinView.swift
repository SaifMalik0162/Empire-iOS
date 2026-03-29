import SwiftUI

struct VIPJoinView: View {
    var body: some View {
        ZStack {
            // Background gradient matching a premium feel
            LinearGradient(colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
                .shadow(color: .yellow.opacity(0.6), radius: 12, x: 0, y: 6)
            Text("Connect+")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Premium Empire perks built around early access, store rewards, and insider updates.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
            Text("Connect+ access is planned after the beta.")
                .font(.headline)
                .foregroundStyle(.yellow)
                .padding(.top, 2)
        }
        .padding(.top, 20)
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 14) {
            perkRow(icon: "bag.fill", title: "Empire Store Discount", subtitle: "Savings on merch and select drops.")
            perkRow(icon: "calendar.badge.clock", title: "Early Show Registration", subtitle: "First access for eligible rides.")
            perkRow(icon: "megaphone.fill", title: "Sneak Peeks & Announcements", subtitle: "Early looks at reveals and updates.")
            perkRow(icon: "gift.fill", title: "Bonus Perks", subtitle: "Extra rewards tied to launches and events.")
            perkRow(icon: "sparkles.rectangle.stack.fill", title: "Exclusive Drops & Giveaways", subtitle: "Priority access to special releases.")
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }

    private func perkRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.yellow.opacity(0.15))
                Image(systemName: icon)
                    .foregroundStyle(.yellow)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.white).font(.headline)
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
            HStack {
                Text("Coming Soon")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.yellow, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.black)
            .shadow(color: .yellow.opacity(0.25), radius: 12, x: 0, y: 8)
        }
        .disabled(true)
        .opacity(0.7)
    }

    private var legal: some View {
        Text("By subscribing you agree to our Terms & Privacy. Benefits may vary by region and event.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.6))
            .multilineTextAlignment(.center)
    }
}

#Preview {
    VIPJoinView()
}
