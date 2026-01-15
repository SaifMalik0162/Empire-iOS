import SwiftUI

struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        section(title: "Quick Help") {
                            HelpGlassCard {
                                HelpRow(icon: "questionmark.circle.fill", title: "FAQ") {
                                    haptic()
                                    // Placeholder action: show FAQ or open link
                                }
                            }
                            HelpGlassCard {
                                HelpRow(icon: "envelope.badge", title: "Contact & Feedback") {
                                    haptic()
                                    // Placeholder: open a unified contact/feedback form or mail composer
                                }
                            }
                        }

                        section(title: "Links") {
                            HelpGlassCard {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 36, height: 36)
                                        .overlay(Image(systemName: "chevron.left.slash.chevron.right").foregroundStyle(Color("EmpireMint")))
                                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("GitHub Repository")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text("Open source & issues")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    Spacer()
                                    if let url = URL(string: "https://github.com/SaifMalik0162/Empire-iOS") {
                                        Link(destination: url) {
                                            Text("Open")
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Capsule().fill(.ultraThinMaterial))
                                                .overlay(Capsule().stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                                                .foregroundStyle(.white)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                            }

                            HelpGlassCard {
                                HelpRow(icon: "doc.text.fill", title: "Terms & Privacy") {
                                    haptic()
                                    // Placeholder: link to terms & privacy
                                }
                            }
                        }

                        section(title: "System Status") {
                            HelpGlassCard {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 10, height: 10)
                                    Text("All systems operational")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                            }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("EmpireMint"))
            VStack(spacing: 10) {
                content()
            }
        }
    }

    private func haptic() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }
}

private struct HelpGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .blendMode(.screen)
            )
            .overlay(ShimmerMask().clipShape(RoundedRectangle(cornerRadius: 18)).opacity(0.35))
            .shadow(color: Color("EmpireMint").opacity(0.22), radius: 14, y: 6)
    }
}

private struct HelpRow: View {
    let icon: String
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: icon).foregroundStyle(Color("EmpireMint")))
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                Text(title)
                    .foregroundStyle(.white)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct ShimmerMask: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        LinearGradient(gradient: Gradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .white.opacity(0.25), location: 0.45),
            .init(color: .clear, location: 0.9)
        ]), startPoint: .topLeading, endPoint: .bottomTrailing)
        .scaleEffect(x: 1.6)
        .offset(x: -120 + phase * 240)
        .onAppear { withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) { phase = 1 } }
        .blendMode(.screen)
        .opacity(0.5)
        .allowsHitTesting(false)
    }
}

#Preview {
    HelpSupportView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
