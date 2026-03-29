import SwiftUI
import StoreKit

struct VIPMembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var joining = false
    @StateObject private var store = StoreKitManager.shared
    @State private var showWelcome = false
    @State private var navPath: [String] = []

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 320)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        // Hero
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                        .blendMode(.screen)
                                )
                                .shadow(color: Color("EmpireMint").opacity(0.25), radius: 16, y: 8)

                            VStack(spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "crown.fill")
                                        .foregroundStyle(Color("EmpireMint"))
                                        .font(.system(size: 20, weight: .bold))
                                    Text("Connect+")
                                        .font(.title3.weight(.bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Group {
                                        if let product = store.products.first(where: { $0.id == store.vipProductID }) {
                                            Text(product.displayPrice)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white.opacity(0.9))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Capsule().fill(.ultraThinMaterial))
                                                .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                        } else {
                                            Text("...")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white.opacity(0.6))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Capsule().fill(.ultraThinMaterial))
                                                .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                        }
                                    }
                                }

                                Text("Unlock store savings, early registration access, and insider Empire updates.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .multilineTextAlignment(.leading)

                                // Perk chips
                                HStack(spacing: 8) {
                                    vipChip(icon: "bag.fill", text: "Store Discount")
                                    vipChip(icon: "calendar.badge.clock", text: "Early Registration")
                                    vipChip(icon: "megaphone.fill", text: "Insider Updates")
                                }

                                // CTA
                                Button {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    Task { await store.purchaseVIP() }
                                } label: {
                                    HStack(spacing: 8) {
                                        if store.purchaseInFlight { ProgressView().tint(.black).scaleEffect(0.8) }
                                        Image(systemName: "sparkles")
                                        Text("Join Connect+")
                                    }
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.black.opacity(0.9))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(colors: [Color("EmpireMint"), Color("EmpireMint").opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: Color("EmpireMint").opacity(0.45), radius: 16, y: 8)
                                    .overlay(
                                        Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(store.purchaseInFlight || store.loading)
                                .scaleEffect(joining ? 0.98 : 1.0)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: joining)
                            }
                            .padding(18)
                        }
                        .padding(.horizontal, 16)

                        if store.isVIP {
                            Text("Your Connect+ membership is active.")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color("EmpireMint"))
                                .padding(.horizontal, 16)
                        }

                        // Benefits list
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Benefits")
                                .font(.headline)
                                .foregroundStyle(.white)

                            benefitRow("Discounts on Empire store drops and merch")
                            benefitRow("Early registration for eligible shows")
                            benefitRow("Sneak peeks and priority announcements")
                            benefitRow("Extra bonuses tied to events and launches")
                            benefitRow("Exclusive drops, raffles, and member giveaways")
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                        .blendMode(.screen)
                                )
                                .shadow(color: Color("EmpireMint").opacity(0.2), radius: 12, y: 6)
                        )
                        .padding(.horizontal, 16)

                        Text("Cancel anytime. Benefits subject to availability and may vary by region.")
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
            .navigationTitle("Connect+ Perks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore") { Task { await store.restorePurchases() } }
                        .disabled(store.loading || store.purchaseInFlight)
                }
            }
            .preferredColorScheme(.dark)
            .navigationDestination(for: String.self) { route in
                if route == "dashboard" { VIPDashboardView() }
            }
        }
        .onChange(of: store.isVIP) { _, new in
            if new { showWelcome = true }
        }
        .fullScreenCover(isPresented: $showWelcome) {
            VIPWelcomeView {
                showWelcome = false
                navPath = ["dashboard"]
            }
        }
        .task {
            await store.loadProducts()
            await store.refreshEntitlements()
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color("EmpireMint"))
            Text(text)
                .foregroundStyle(.white)
                .font(.subheadline)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }

    private func vipChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}
