import SwiftUI

struct MeetsView: View {
    let meets: [Meet]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 80)

                ForEach(meets) { meet in
                    ZStack {
                        // Card background
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.05), Color.white.opacity(0.15), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ).blendMode(.overlay)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color("EmpireMint").opacity(0.6), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: Color("EmpireMint").opacity(0.25), radius: 15, x: 0, y: 8)
                            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                        
                        // Card content
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(meet.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .shadow(color: Color("EmpireMint").opacity(0.7), radius: 2)
                                Text("\(meet.city) · \(meet.dateString)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color("EmpireMint"))
                                .shadow(color: Color("EmpireMint").opacity(0.6), radius: 2)
                        }
                        .padding(20)
                    }
                    .frame(height: 110)
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 60)
            }
        }
        .background(
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Preview
struct MeetsView_Previews: PreviewProvider {
    static var previews: some View {
        MeetsView(meets: [
            Meet(title: "Winter Cruise", city: "Toronto", date: Date()),
            Meet(title: "Stage 2 Meetup", city: "Vancouver", date: Date().addingTimeInterval(86400 * 5)),
            Meet(title: "Track Day", city: "Montreal", date: Date().addingTimeInterval(86400 * 10))
        ])
        .preferredColorScheme(.dark)
    }
}
