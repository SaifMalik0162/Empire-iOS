import SwiftUI

struct ExploreFeedView: View {
    let communityCars: [Car]
    @Binding var likedCommunity: Set<UUID>
    var onClose: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedFilter: String = "All"

    private var filtered: [Car] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedFilter == "All" {
            return communityCars
        }
        return communityCars.filter { car in
            let matchesSearch = searchText.isEmpty ? true : car.name.localizedCaseInsensitiveContains(searchText) || car.description.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool = {
                switch selectedFilter {
                case "Jailbreak": return car.isJailbreak
                case "Stock": return car.stage == 0
                case "Stage 1": return car.stage == 1
                case "Stage 2": return car.stage == 2
                case "Stage 3": return car.stage == 3
                default: return true
                }
            }()
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background Gradient
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Subtle EmpireMint top glow
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                // MARK: - Content
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        Color.clear.frame(height: 6)

                        ForEach(filtered.indices, id: \.self) { idx in
                            let car = filtered[idx]
                            FeedCard(car: car, isLiked: likedCommunity.contains(car.id)) {
                                if likedCommunity.contains(car.id) { likedCommunity.remove(car.id) } else { likedCommunity.insert(car.id) }
                            }
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        Color.clear.frame(height: 30)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Community Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { onClose(); dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 12) {
                        TextField("Search builds, tags, users...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 34)
                            .frame(maxWidth: 280)
                            .shadow(color: Color.white.opacity(0.03), radius: 6)

                        Menu {
                            Button("All") { selectedFilter = "All" }
                            Button("Jailbreak") { selectedFilter = "Jailbreak" }
                            Button("Stock") { selectedFilter = "Stock" }
                            Button("Stage 1") { selectedFilter = "Stage 1" }
                            Button("Stage 2") { selectedFilter = "Stage 2" }
                            Button("Stage 3") { selectedFilter = "Stage 3" }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(selectedFilter)
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color("EmpireMint").opacity(0.6), lineWidth: 1.2))
                            .foregroundStyle(Color("EmpireMint"))
                        }
                    }
                }
            }
            .toolbarBackground(
                LinearGradient(colors: [Color.black.opacity(0.3), Color.black.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

private struct FeedCard: View {
    let car: Car
    var isLiked: Bool
    var onToggleLike: () -> Void

    @State private var showHeart: Bool = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                let size = proxy.size
                Image(car.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .overlay(
                        LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.6), radius: 18, x: 0, y: 8)
            }
            .frame(height: 300)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(car.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(car.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        Button(action: {
                            onToggleLike()
                            withAnimation(.spring()) { showHeart = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation { showHeart = false } }
                        }) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? Color("EmpireMint") : .white)
                                .padding(10)
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        if let url = URL(string: "https://example.com/cars/\(car.id.uuidString)") {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Circle().fill(.ultraThinMaterial))
                            }
                        }
                    }
                }
                .padding(12)

                HStack(spacing: 8) {
                    Group {
                        if car.isJailbreak {
                            BadgeView(text: "Jailbreak", color: .purple)
                        } else if car.stage == 0 {
                            BadgeView(text: "Stock", color: .gray)
                        } else {
                            BadgeView(text: "Stage \(car.stage)", color: stageTint(for: car.stage))
                        }
                    }
                    BadgeView(text: "\(car.horsepower) HP", color: .cyan)
                    Spacer()
                }
                .padding([.leading, .bottom, .trailing], 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.15))
                    .blur(radius: 4)
                    .opacity(0.0001)
            )
        }
        .cornerRadius(18)
    }
}

private struct BadgeView: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
            .foregroundStyle(.white)
    }
}

private func stageTint(for stage: Int) -> Color {
    switch stage {
    case 1: return Color("EmpireMint")
    case 2: return .yellow
    case 3: return .red
    default: return .gray
    }
}
