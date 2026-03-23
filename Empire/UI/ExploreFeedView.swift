import SwiftUI

struct ExploreFeedView: View {

    var communityCars: [Car] = []
    var userCars: [Car] = []
    @Binding var likedCommunity: Set<UUID>
    var onClose: () -> Void = {}

    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = CommunityViewModel()

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedFilter: FeedFilter = .all
    @State private var showShareToFeed: Bool = false

    private var currentUserId: String { UserDefaults.standard.string(forKey: "currentUserId") ?? "" }

    private var filtered: [CommunityPost] {
        vm.posts.filter { post in
            let matchesSearch: Bool = {
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !q.isEmpty else { return true }
                return post.carName.lowercased().contains(q)
                    || (post.make?.lowercased().contains(q) ?? false)
                    || (post.model?.lowercased().contains(q) ?? false)
                    || (post.caption?.lowercased().contains(q) ?? false)
                    || (post.username?.lowercased().contains(q) ?? false)
            }()
            let matchesFilter: Bool = {
                switch selectedFilter {
                case .all: return true
                case .jailbreak: return post.isJailbreak
                case .stock: return post.stage == 0 && !post.isJailbreak
                case .stage1: return post.stage == 1
                case .stage2: return post.stage == 2
                case .stage3: return post.stage == 3
                case .liked: return post.isLiked
                }
            }()
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                if vm.isLoading && vm.posts.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView().tint(Color("EmpireMint")).scaleEffect(1.3)
                        Text("Loading community feed…")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                } else if let err = vm.errorMessage, vm.posts.isEmpty {
                    emptyErrorView(message: err)
                } else {
                    postList
                }
            }
            .navigationTitle("Community Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(
                LinearGradient(colors: [Color.black.opacity(0.3), Color.black.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task { await vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .empireCommunityDidPost)) { _ in
            Task { await vm.refresh() }
        }
        .sheet(isPresented: $showShareToFeed) {
            ShareToFeedSheet(userCars: userCars) { _ in }
                .environmentObject(authViewModel)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Post list

    private var postList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Filter chips
                filterChips
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                ForEach(filtered) { post in
                    FeedPostCard(
                        post: post,
                        currentUserId: currentUserId,
                        communityVM: vm,
                        photoURL: vm.photoURL(for: post),
                        avatarURL: vm.avatarURL(for: post)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .onAppear {
                        if post.id == filtered.last?.id {
                            Task { await vm.loadMore() }
                        }
                    }
                }

                // Inline empty state
                if filtered.isEmpty && !vm.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 30))
                            .foregroundStyle(Color("EmpireMint").opacity(0.5))
                        Text("No posts match")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Try a different filter or search term.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }

                if vm.isLoadingMore {
                    ProgressView()
                        .tint(Color("EmpireMint"))
                        .padding(.vertical, 20)
                }

                if !vm.hasMore && !filtered.isEmpty {
                    Text("You've seen it all 🏁")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.vertical, 20)
                }

                Color.clear.frame(height: 60)
            }
        }
        .refreshable { await vm.refresh() }
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FeedFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Empty states

    private func emptyErrorView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color("EmpireMint").opacity(0.7))
            Text("Couldn't load feed")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.refresh() } }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("EmpireMint"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(Color("EmpireMint").opacity(0.6), lineWidth: 1))
        }
        .padding(24)
    }

    private var emptyFilterView: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Color("EmpireMint").opacity(0.5))
            Text("No posts match")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Try a different filter or search term.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.system(size: 12))
                    TextField("Search builds, users…", text: $searchText)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.45))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .layoutPriority(1)

                if !userCars.isEmpty {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showShareToFeed = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Share")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color("EmpireMint"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color("EmpireMint").opacity(0.7), Color("EmpireMint").opacity(0.3)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }
            }
        }
    }
}

// MARK: - Feed filter enum

enum FeedFilter: CaseIterable {
    case all, liked, stock, stage1, stage2, stage3, jailbreak

    var label: String {
        switch self {
        case .all:       return "All"
        case .liked:     return "Liked"
        case .stock:     return "Stock"
        case .stage1:    return "Stage 1"
        case .stage2:    return "Stage 2"
        case .stage3:    return "Stage 3"
        case .jailbreak: return "Jailbreak"
        }
    }

    /// Icon shown on the pill
    var icon: String {
        switch self {
        case .all:       return "square.grid.2x2.fill"
        case .liked:     return "heart.fill"
        case .stock:     return "car.fill"
        case .stage1:    return "bolt.fill"
        case .stage2:    return "bolt.fill"
        case .stage3:    return "flame.fill"
        case .jailbreak: return "lock.open.fill"
        }
    }

    /// Accent color when selected
    var accentColor: Color {
        switch self {
        case .all:       return Color("EmpireMint")
        case .liked:     return Color(red: 0.95, green: 0.3, blue: 0.45)   // warm red-pink
        case .stock:     return Color(white: 0.65)                          // gray
        case .stage1:    return Color("EmpireMint")                         // mint
        case .stage2:    return Color(red: 0.95, green: 0.78, blue: 0.1)   // yellow
        case .stage3:    return Color(red: 0.95, green: 0.28, blue: 0.22)  // red
        case .jailbreak: return Color(red: 0.65, green: 0.35, blue: 0.95)  // purple
        }
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let filter: FeedFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: filter.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(filter.label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? selectedForeground : .white.opacity(0.65))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? filter.accentColor.opacity(0.2) : Color.white.opacity(0.07))
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? filter.accentColor.opacity(0.85) : Color.white.opacity(0.15),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? filter.accentColor.opacity(0.3) : .clear,
                radius: 6, x: 0, y: 3
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var selectedForeground: Color {
        switch filter {
        case .stage2: return Color(red: 0.92, green: 0.72, blue: 0.05)
        default:      return filter.accentColor
        }
    }
}

// MARK: - Individual post card

struct FeedPostCard: View {
    let post: CommunityPost
    let currentUserId: String
    @ObservedObject var communityVM: CommunityViewModel
    let photoURL: URL?
    let avatarURL: URL?

    @State private var showHeartBurst = false
    @State private var heartScale: CGFloat = 0.6
    @State private var heartOpacity: Double = 0.0
    @State private var showDeleteConfirm = false
    @State private var tilt: CGSize = .zero

    private var isOwnPost: Bool { post.userId == currentUserId }

    private var stageAccent: Color {
        if post.isJailbreak { return .purple }
        switch post.stage {
        case 1: return Color("EmpireMint")
        case 2: return .yellow
        case 3: return .red
        default: return Color(white: 0.6)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // Glass card base + shimmer
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                        .blendMode(.screen)
                )
                .overlay(PostShimmer().clipShape(RoundedRectangle(cornerRadius: 24)))
                .shadow(color: stageAccent.opacity(0.2), radius: 20, x: 0, y: 12)
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 6)
                .rotation3DEffect(.degrees(Double(tilt.width) * 0.04), axis: (x: 0, y: 1, z: 0))
                .rotation3DEffect(.degrees(Double(-tilt.height) * 0.04), axis: (x: 1, y: 0, z: 0))

            // Full-bleed hero photo
            Group {
                if let url = photoURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 340).clipped()
                                .opacity(0.62)
                        case .empty:
                            ZStack { Color.white.opacity(0.04); ProgressView().tint(Color("EmpireMint")) }
                                .frame(height: 340)
                        default:
                            Color.white.opacity(0.04).frame(height: 340)
                        }
                    }
                } else {
                    ZStack {
                        Color.white.opacity(0.04)
                        Image(systemName: "car.fill").font(.system(size: 48))
                            .foregroundStyle(Color("EmpireMint").opacity(0.3))
                    }
                    .frame(height: 340)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.0), .black.opacity(0.1), .black.opacity(0.78)],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            )
            .overlay(heartBurst)
            .onTapGesture(count: 2) { doubleTapLike() }

            // Overlaid content
            VStack(spacing: 0) {
                // Top — avatar + username + menu
                HStack(spacing: 10) {
                    avatarView.frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.username ?? "Empire Driver")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4)
                        Text(post.createdAt.relativeFormatted)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .shadow(color: .black.opacity(0.6), radius: 4)
                    }
                    Spacer()
                    if isOwnPost {
                        Menu {
                            Button(role: .destructive) { showDeleteConfirm = true } label: {
                                Label("Delete post", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.75))
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()

                // Bottom — car info, chips, like/share, caption
                VStack(alignment: .leading, spacing: 10) {
                    // Car name + class
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(carDisplayName)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4)
                            .lineLimit(1)
                        if let cls = post.vehicleClass {
                            Text(cls.components(separatedBy: " - ").first ?? "")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    // Chips + actions
                    HStack(spacing: 7) {
                        // Stage chip — colored text + fill
                        Text(stageLabel.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(stageAccent)
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .background(Capsule().fill(stageAccent.opacity(0.15)))
                            .overlay(Capsule().stroke(stageAccent.opacity(0.7), lineWidth: 1))

                        // HP chip — cyan colored text
                        Text("\(post.horsepower) HP")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.cyan)
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .background(Capsule().fill(Color.cyan.opacity(0.15)))
                            .overlay(Capsule().stroke(Color.cyan.opacity(0.6), lineWidth: 1))

                        Spacer()

                        // Like
                        Button { Task { await communityVM.toggleLike(postId: post.id) } } label: {
                            HStack(spacing: 5) {
                                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                    .foregroundStyle(post.isLiked ? Color("EmpireMint") : .white.opacity(0.85))
                                if post.likesCount > 0 {
                                    Text("\(post.likesCount)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                            .font(.system(size: 15))
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Capsule().fill(.ultraThinMaterial))
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        // Share
                        if let shareURL = URL(string: "https://empireontario.shop/cars/\(post.id.uuidString)") {
                            ShareLink(item: shareURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(8)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            }
                        }
                    }

                    // Caption
                    if let caption = post.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(3)
                            .shadow(color: .black.opacity(0.4), radius: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                .padding(.top, 10)
            }
            .frame(height: 340)

            // Stage accent glow on bottom edge
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [stageAccent.opacity(0.5), .clear],
                                   startPoint: .bottomLeading, endPoint: .topTrailing),
                    lineWidth: 1.5
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let w = max(-28, min(28, v.translation.width))
                    let h = max(-28, min(28, v.translation.height))
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) { tilt = CGSize(width: w, height: h) }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { tilt = .zero }
                }
        )
        .confirmationDialog("Delete this post?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await communityVM.deletePost(postId: post.id) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Helpers

    private var stageLabel: String {
        if post.isJailbreak { return "Jailbreak" }
        if post.stage == 0  { return "Stock" }
        return "Stage \(post.stage)"
    }

    private var carDisplayName: String {
        let parts = [post.make, post.model].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? post.carName : parts.joined(separator: " ")
    }

    private var avatarView: some View {
        Group {
            if let url = avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Image(systemName: "person.fill").resizable().scaledToFit().padding(8)
                            .foregroundStyle(Color("EmpireMint"))
                    }
                }
            } else {
                Image(systemName: "person.fill").resizable().scaledToFit().padding(8)
                    .foregroundStyle(Color("EmpireMint"))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 4)
    }

    private var heartBurst: some View {
        Group {
            if showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color("EmpireMint"))
                    .shadow(color: Color("EmpireMint").opacity(0.6), radius: 12)
                    .scaleEffect(heartScale)
                    .opacity(heartOpacity)
                    .allowsHitTesting(false)
            }
        }
    }

    private func doubleTapLike() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if !post.isLiked { Task { await communityVM.toggleLike(postId: post.id) } }
        showHeartBurst = true
        heartScale = 0.5; heartOpacity = 0
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { heartScale = 1.1; heartOpacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) { heartScale = 0.9; heartOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showHeartBurst = false }
        }
    }
}

// MARK: - Post card shimmer

private struct PostShimmer: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white.opacity(0.06), location: 0.45),
                .init(color: .clear, location: 0.9)
            ]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .scaleEffect(x: 1.8)
        .offset(x: -120 + phase * 240)
        .onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { phase = 1 } }
        .blendMode(.screen)
        .allowsHitTesting(false)
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

// MARK: - Date formatting

private extension Date {
    var relativeFormatted: String {
        let seconds = -timeIntervalSinceNow
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        if seconds < 604800 { return "\(Int(seconds / 86400))d ago" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: self)
    }
}
