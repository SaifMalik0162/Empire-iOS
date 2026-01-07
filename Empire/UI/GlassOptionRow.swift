import SwiftUI

struct GlassOptionRow: View {
    let icon: String
    let title: String
    var destructive: Bool = false

    var body: some View {
        Button {} label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            destructive
                            ? Color.red.opacity(0.18)
                            : Color("EmpireMint").opacity(0.18)
                        )
                        .frame(width: 38, height: 38)

                    Image(systemName: icon)
                        .foregroundColor(
                            destructive ? .red : Color("EmpireMint")
                        )
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(title)
                    .foregroundColor(.white)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        (destructive ? Color.red : Color("EmpireMint")).opacity(0.5),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .shadow(color: Color("EmpireMint").opacity(0.22), radius: 8, y: 5)
    }
}
