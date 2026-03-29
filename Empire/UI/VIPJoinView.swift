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
            Text("Empire VIP")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Unlock community perks built for car enthusiasts across North America.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
            Text("VIP access is planned after the beta.")
                .font(.headline)
                .foregroundStyle(.yellow)
                .padding(.top, 2)
        }
        .padding(.top, 20)
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 14) {
            perkRow(icon: "sparkles", title: "VIP Meet Access", subtitle: "Early RSVP and priority entry at local meets.")
            perkRow(icon: "person.3.fill", title: "Crew Finder", subtitle: "Discover and join local crews and drives.")
            perkRow(icon: "text.bubble.fill", title: "VIP Threads", subtitle: "Member-only posts, polls, and shoutouts.")
            perkRow(icon: "camera.fill", title: "Spotlight Features", subtitle: "Get featured on the community feed.")
            perkRow(icon: "ticket.fill", title: "Event Perks", subtitle: "Discounts and giveaways at partner events.")
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
                Text(subtitle).foregroundStyle(.white.opacity(0.7)).font(.subheadline)
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
        VStack(spacing: 6) {
            Text("Beta testers will get an early look at the VIP roadmap before memberships open.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
            Text("Benefits may vary by region and event.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

#Preview {
    VIPJoinView()
}
