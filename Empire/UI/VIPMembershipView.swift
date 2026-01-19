import SwiftUI

struct VIPMembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var joining = false

    var body: some View {
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
                                Text("Empire VIP")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("$7.99/mo")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(.ultraThinMaterial))
                                    .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                            }

                            Text("Unlock priority access, exclusive drops, and premium perks across the Empire experience.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.leading)

                            // Perk chips
                            HStack(spacing: 8) {
                                vipChip(icon: "bolt.fill", text: "Priority Access")
                                vipChip(icon: "bag.fill.badge.plus", text: "Exclusive Drops")
                                vipChip(icon: "gift.fill", text: "2x Rewards")
                            }

                            // CTA
                            Button {
                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.impactOccurred()
                                joining = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    joining = false
                                }
                                // TODO: Wire to StoreKit flow
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                    Text("Join VIP")
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
                            .scaleEffect(joining ? 0.98 : 1.0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: joining)
                        }
                        .padding(18)
                    }
                    .padding(.horizontal, 16)

                    // Benefits list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Benefits")
                            .font(.headline)
                            .foregroundStyle(.white)

                        benefitRow("Priority check-in at shows")
                        benefitRow("Early access to limited merch drops")
                        benefitRow("Double reward points on purchases")
                        benefitRow("VIP-only giveaways & events")
                        benefitRow("Custom profile badge")
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
        .navigationTitle("VIP Perks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .preferredColorScheme(.dark)
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
