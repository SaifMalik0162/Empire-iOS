import SwiftUI
import StoreKit
import Combine

struct VIPJoinView: View {
    @StateObject private var store = StoreKitManager.shared
    @State private var showWelcome = false
    @State private var showError = false

    private var vipProduct: Product? { store.products.first(where: { $0.id == store.vipProductID }) }

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
                restore
                legal
            }
            .padding(24)
        }
        .onReceive(store.$errorMessage.compactMap { $0 }) { _ in
            showError = true
        }
        .alert("Purchase Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        }, message: {
            Text(store.errorMessage ?? "Unknown error")
        })
        .fullScreenCover(isPresented: $showWelcome) {
            VIPWelcomeView(onContinue: {})
        }
        .task {
            await store.loadProducts()
        }
        .onChange(of: store.isVIP) { _, new in
            if new { showWelcome = true }
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
            if let price = vipProduct?.displayPrice {
                Text("Only \(price) / month")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .padding(.top, 2)
            }
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

    private var restore: some View {
        Button("Restore Purchases") {
            Task { await store.restorePurchases() }
        }
        .foregroundStyle(.white.opacity(0.8))
    }

    private var legal: some View {
        VStack(spacing: 6) {
            if let blurb = subscriptionBlurb {
                Text(blurb)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text("By subscribing you agree to our Terms & Privacy. Benefits may vary by region and event.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var subscriptionBlurb: String? {
        guard let sub = vipProduct?.subscription else { return nil }
        let period = sub.subscriptionPeriod
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "period"
        }
        let duration = "\(period.value) \(unit)\(period.value > 1 ? "s" : "")"
        return "Auto-renews every \(duration). Cancel anytime in Settings."
    }
}

#Preview {
    VIPJoinView()
}
