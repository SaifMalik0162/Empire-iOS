import SwiftUI
import SwiftData

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
                case .all:       return true
                case .jailbreak: return post.isJailbreak
                case .stock:     return post.stage == 0 && !post.isJailbreak
                case .stage1:    return post.stage == 1
                case .stage2:    return post.stage == 2
                case .stage3:    return post.stage == 3
                case .liked:     return post.isLiked
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
                            .font(.caption).foregroundStyle(.white.opacity(0.7))
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
                filterChips
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                ForEach(filtered) { post in
                    FeedPostCard(
                        post: post,
                        currentUserId: currentUserId,
                        communityVM: vm,
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

                if filtered.isEmpty && !vm.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 30))
                            .foregroundStyle(Color("EmpireMint").opacity(0.5))
                        Text("No posts match")
                            .font(.headline).foregroundStyle(.white)
                        Text("Try a different filter or search term.")
                            .font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }

                if vm.isLoadingMore {
                    ProgressView().tint(Color("EmpireMint")).padding(.vertical, 20)
                }

                if !vm.hasMore && !filtered.isEmpty {
                    Text("You've seen it all 🏁")
                        .font(.caption).foregroundStyle(.white.opacity(0.4))
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
                    FilterChip(filter: filter, isSelected: selectedFilter == filter) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedFilter = filter }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Empty / error states

    private func emptyErrorView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36)).foregroundStyle(Color("EmpireMint").opacity(0.7))
            Text("Couldn't load feed").font(.headline).foregroundStyle(.white)
            Text(message).font(.caption).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.refresh() } }
                .font(.caption.weight(.semibold)).foregroundStyle(Color("EmpireMint"))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(Color("EmpireMint").opacity(0.6), lineWidth: 1))
        }
        .padding(24)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { onClose(); dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            }
        }
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.5)).font(.system(size: 12))
                    TextField("Search builds, users…", text: $searchText)
                        .font(.subheadline).foregroundStyle(.white)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.45)).font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .layoutPriority(1)

                if !userCars.isEmpty {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showShareToFeed = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 13, weight: .semibold))
                            Text("Share").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color("EmpireMint"))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(LinearGradient(colors: [Color("EmpireMint").opacity(0.7), Color("EmpireMint").opacity(0.3)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                    }
                    .buttonStyle(.plain).fixedSize()
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

    var accentColor: Color {
        switch self {
        case .all:       return Color("EmpireMint")
        case .liked:     return Color(red: 0.95, green: 0.3,  blue: 0.45)
        case .stock:     return Color(white: 0.65)
        case .stage1:    return Color("EmpireMint")
        case .stage2:    return Color(red: 0.95, green: 0.78, blue: 0.1)
        case .stage3:    return Color(red: 0.95, green: 0.28, blue: 0.22)
        case .jailbreak: return Color(red: 0.65, green: 0.35, blue: 0.95)
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
                Image(systemName: filter.icon).font(.system(size: 10, weight: .semibold))
                Text(filter.label).font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? selectedForeground : .white.opacity(0.65))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? filter.accentColor.opacity(0.2) : Color.white.opacity(0.07)))
            .overlay(Capsule().stroke(isSelected ? filter.accentColor.opacity(0.85) : Color.white.opacity(0.15),
                                      lineWidth: isSelected ? 1.5 : 1))
            .shadow(color: isSelected ? filter.accentColor.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var selectedForeground: Color {
        filter == .stage2 ? Color(red: 0.92, green: 0.72, blue: 0.05) : filter.accentColor
    }
}

// MARK: - Individual post card

struct FeedPostCard: View {
    let post: CommunityPost
    let currentUserId: String
    @ObservedObject var communityVM: CommunityViewModel
    let avatarURL: URL?
    var allowsProfileNavigation = true

    @State private var showHeartBurst = false
    @State private var heartScale: CGFloat = 0.6
    @State private var heartOpacity: Double = 0.0
    @State private var showDeleteConfirm = false
    @State private var showComments = false
    @State private var showUserPosts = false
    @State private var tilt: CGSize = .zero
    @State private var currentPhotoIndex = 0
    @State private var photoDragOffset: CGFloat = 0

    private var isOwnPost: Bool {
        post.userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == currentUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    private var photoURLs: [URL] { communityVM.photoURLs(for: post) }

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

            // Glass card base
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        .blendMode(.screen)
                )
                .overlay(PostShimmer().clipShape(RoundedRectangle(cornerRadius: 24)))
                .shadow(color: stageAccent.opacity(0.2), radius: 20, x: 0, y: 12)
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 6)
                .rotation3DEffect(.degrees(Double(tilt.width) * 0.04), axis: (x: 0, y: 1, z: 0))
                .rotation3DEffect(.degrees(Double(-tilt.height) * 0.04), axis: (x: 1, y: 0, z: 0))

            // Hero photo
            Group {
                if !photoURLs.isEmpty {
                    if photoURLs.count == 1, let url = photoURLs.first {
                        communityPhoto(url: url)
                    } else {
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                ForEach(Array(photoURLs.enumerated()), id: \.offset) { pair in
                                    communityPhoto(url: pair.element)
                                        .frame(width: geo.size.width, height: 340)
                                }
                            }
                            .offset(x: -CGFloat(currentPhotoIndex) * geo.size.width + photoDragOffset)
                            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: currentPhotoIndex)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 12)
                                    .onChanged { value in
                                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                        photoDragOffset = value.translation.width
                                    }
                                    .onEnded { value in
                                        defer { photoDragOffset = 0 }
                                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                        let threshold = geo.size.width * 0.18
                                        if value.translation.width < -threshold {
                                            currentPhotoIndex = min(currentPhotoIndex + 1, photoURLs.count - 1)
                                        } else if value.translation.width > threshold {
                                            currentPhotoIndex = max(currentPhotoIndex - 1, 0)
                                        }
                                    }
                            )
                        }
                        .frame(height: 340)
                        .clipped()
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
                LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.1), .black.opacity(0.78)],
                               startPoint: .top, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            )
            .overlay(alignment: .topTrailing) {
                if photoURLs.count > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(currentPhotoIndex + 1)/\(photoURLs.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.42)))
                    .padding(14)
                }
            }
            .overlay {
                if photoURLs.count > 1 {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .highPriorityGesture(photoSwipeGesture)
                }
            }
            .overlay(heartBurst)
            .onTapGesture(count: 2) { doubleTapLike() }

            topOverlay
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            bottomOverlay
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // Stage accent glow
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
        .onLongPressGesture(minimumDuration: 0.45) {
            guard isOwnPost else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showDeleteConfirm = true
        }
        .confirmationDialog("Delete this post?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await communityVM.deletePost(postId: post.id) } }
            Button("Cancel", role: .cancel) {}
        }
        // Comment sheet
        .sheet(isPresented: $showComments) {
            CommentSheetView(
                post: post,
                currentUserId: currentUserId,
                communityVM: communityVM
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showUserPosts) {
            CommunityProfilePostsView(
                userId: post.userId,
                username: post.username,
                avatarURL: avatarURL,
                currentUserId: currentUserId
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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

    private var makeModelLine: String? {
        let parts: [String] = [post.make, post.model].compactMap { value in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    private var avatarView: some View {
        Group {
            if let url = avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: placeholderPersonIcon
                    }
                }
            } else {
                placeholderPersonIcon
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 4)
    }

    private var placeholderPersonIcon: some View {
        Image(systemName: "person.fill").resizable().scaledToFit().padding(8)
            .foregroundStyle(Color("EmpireMint"))
    }

    @ViewBuilder
    private var profileIdentity: some View {
        let content = HStack(spacing: 10) {
            avatarView.frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(post.username ?? "Empire Driver")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4)
                Text(post.createdAt.relativeFormatted)
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
        }

        if allowsProfileNavigation {
            Button {
                showUserPosts = true
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var topOverlay: some View {
        HStack(spacing: 10) {
            profileIdentity
            Spacer()
        }
    }

    private var bottomOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(post.carName)
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

                if let makeModelLine, !makeModelLine.isEmpty, makeModelLine != post.carName {
                    Text(makeModelLine)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.35), radius: 3)
                }
            }
            .padding(.top, 10)

            HStack(spacing: 7) {
                Text(stageLabel.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(stageAccent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(stageAccent.opacity(0.15)))
                    .overlay(Capsule().stroke(stageAccent.opacity(0.7), lineWidth: 1))

                Text("\(post.horsepower) HP")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cyan)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.6), lineWidth: 1))

                Spacer()

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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button { showComments = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .foregroundStyle(.white.opacity(0.85))
                        if post.commentsCount > 0 {
                            Text("\(post.commentsCount)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .font(.system(size: 15))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)

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

            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
        }
    }

    private func communityPhoto(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .clipped()
                    .opacity(0.62)
            case .empty:
                ZStack { Color.white.opacity(0.04); ProgressView().tint(Color("EmpireMint")) }
                    .frame(height: 340)
            default:
                Color.white.opacity(0.04).frame(height: 340)
            }
        }
    }

    private var photoSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                photoDragOffset = value.translation.width
            }
            .onEnded { value in
                defer { photoDragOffset = 0 }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let threshold: CGFloat = 60
                if value.translation.width < -threshold {
                    currentPhotoIndex = min(currentPhotoIndex + 1, photoURLs.count - 1)
                } else if value.translation.width > threshold {
                    currentPhotoIndex = max(currentPhotoIndex - 1, 0)
                }
            }
    }

    private var heartBurst: some View {
        Group {
            if showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80)).foregroundStyle(Color("EmpireMint"))
                    .shadow(color: Color("EmpireMint").opacity(0.6), radius: 12)
                    .scaleEffect(heartScale).opacity(heartOpacity)
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

struct CommunityProfilePostsView: View {
    let userId: String
    let username: String?
    let avatarURL: URL?
    let currentUserId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: CommunityViewModel
    @State private var currentHeaderCar: Car? = nil
    @State private var pendingDeletePost: CommunityPost? = nil
    @State private var isDeleteMode = false

    private let carsService = SupabaseCarsService()

    init(userId: String, username: String?, avatarURL: URL?, currentUserId: String) {
        self.userId = userId
        self.username = username
        self.avatarURL = avatarURL
        self.currentUserId = currentUserId
        _vm = StateObject(wrappedValue: CommunityViewModel(userId: userId))
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
                        ProgressView().tint(Color("EmpireMint")).scaleEffect(1.2)
                        Text("Loading posts…")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            profileHeader
                                .padding(.horizontal, 16)
                                .padding(.top, 10)

                            if let errorMessage = vm.errorMessage, vm.posts.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(Color("EmpireMint").opacity(0.7))
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                    Button("Retry") {
                                        Task { await vm.refresh() }
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color("EmpireMint"))
                                }
                                .padding(20)
                            } else if vm.posts.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "sparkles.rectangle.stack")
                                        .font(.system(size: 28))
                                        .foregroundStyle(Color("EmpireMint").opacity(0.55))
                                    Text(emptyTitle)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text(emptySubtitle)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.65))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, 28)
                                .padding(.top, 36)
                            } else {
                                LazyVGrid(columns: gridColumns, spacing: 12) {
                                    ForEach(vm.posts) { post in
                                        CommunityProfileGridTile(
                                            post: post,
                                            photoURL: vm.photoURL(for: post),
                                            showsDeleteButton: isOwnProfile && isDeleteMode,
                                            onDelete: {
                                                pendingDeletePost = post
                                            }
                                        )
                                        .onAppear {
                                            if post.id == vm.posts.last?.id {
                                                Task { await vm.loadMore() }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)

                                if vm.isLoadingMore {
                                    ProgressView()
                                        .tint(Color("EmpireMint"))
                                        .padding(.vertical, 12)
                                }
                            }

                            Color.clear.frame(height: 32)
                        }
                    }
                    .refreshable {
                        await vm.refresh()
                        await refreshHeaderCar()
                    }
                }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                if isOwnProfile, !vm.posts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isDeleteMode ? "Done" : "Delete") {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                isDeleteMode.toggle()
                            }
                        }
                        .foregroundStyle(isDeleteMode ? Color("EmpireMint") : .red.opacity(0.9))
                        .fontWeight(.semibold)
                    }
                }
            }
            .confirmationDialog(
                "Delete this post?",
                isPresented: Binding(
                    get: { pendingDeletePost != nil },
                    set: { if !$0 { pendingDeletePost = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let post = pendingDeletePost else { return }
                    Task { await vm.deletePost(postId: post.id) }
                    pendingDeletePost = nil
                    if vm.posts.count <= 1 {
                        isDeleteMode = false
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletePost = nil
                }
            } message: {
                if let pendingDeletePost {
                    Text("This will permanently remove \(pendingDeletePost.carName) from the community feed.")
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await vm.refresh()
            await refreshHeaderCar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .empireCommunityDidPost)) { _ in
            Task {
                await vm.refresh()
                await refreshHeaderCar()
                if vm.posts.isEmpty {
                    isDeleteMode = false
                }
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("@\(displayHandle)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)

                    Circle()
                        .fill(Color("EmpireMint").opacity(0.6))
                        .frame(width: 4, height: 4)

                    Text("\(vm.totalPostsCount) post\(vm.totalPostsCount == 1 ? "" : "s")")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 6) {
                profileMetric(value: "\(vm.totalPostsCount)", label: "Posts")
                if let headerStats = currentHeaderStats {
                    HStack(spacing: 6) {
                        Text("\(headerStats.horsepower) HP")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.cyan.opacity(0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.cyan.opacity(0.16)))
                            .overlay(Capsule().stroke(Color.cyan.opacity(0.45), lineWidth: 1))

                        Text(headerStats.stageLabel)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(headerStats.tint.opacity(0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(headerStats.tint.opacity(0.16)))
                            .overlay(Capsule().stroke(headerStats.tint.opacity(0.45), lineWidth: 1))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color("EmpireMint").opacity(0.35), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, y: 8)
    }

    private var communityAvatarPlaceholder: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            Image(systemName: "person.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color("EmpireMint").opacity(0.75))
        }
    }

    private var avatar: some View {
        Group {
            if let avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        communityAvatarPlaceholder
                    }
                }
            } else {
                communityAvatarPlaceholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var displayName: String {
        if let username, !username.isEmpty {
            return username
        }
        return userId == currentUserId ? "You" : "Empire Driver"
    }

    private var displayHandle: String {
        if let username, !username.isEmpty {
            return username.lowercased()
        }
        return userId == currentUserId ? "you" : "driver"
    }

    private var emptyTitle: String {
        userId == currentUserId ? "You haven't posted yet" : "\(displayName) hasn't posted yet"
    }

    private var emptySubtitle: String {
        userId == currentUserId
            ? "Share one of your builds to start your community profile."
            : "There aren't any public community posts from this driver yet."
    }

    private var isOwnProfile: Bool {
        userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == currentUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func profileMetric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func stageTintForHeader(_ post: CommunityPost) -> Color {
        if post.isJailbreak { return .purple }
        switch post.stage {
        case 1: return Color("EmpireMint")
        case 2: return .yellow
        case 3: return .red
        default: return .gray
        }
    }

    private func latestStageLabel(for post: CommunityPost) -> String {
        if post.isJailbreak { return "JAILBREAK" }
        return post.stage == 0 ? "STOCK" : "STAGE \(post.stage)"
    }

    private var currentHeaderStats: (horsepower: Int, stageLabel: String, tint: Color)? {
        if let currentHeaderCar {
            return (
                horsepower: currentHeaderCar.horsepower,
                stageLabel: currentHeaderCar.isJailbreak ? "JAILBREAK" : (currentHeaderCar.stage == 0 ? "STOCK" : "STAGE \(currentHeaderCar.stage)"),
                tint: currentHeaderCar.isJailbreak ? .purple : stageTint(for: currentHeaderCar.stage)
            )
        }

        guard let latest = vm.posts.first else { return nil }
        return (
            horsepower: latest.horsepower,
            stageLabel: latestStageLabel(for: latest),
            tint: stageTintForHeader(latest)
        )
    }

    @MainActor
    private func refreshHeaderCar() async {
        if userId == currentUserId {
            let localCars = LocalStore.shared.fetchCars(context: modelContext, userKey: userId)
            if let resolved = resolveHeaderCar(from: localCars) {
                currentHeaderCar = resolved
                return
            }
        }

        do {
            let remoteCars = try await carsService.fetchCars(for: userId)
            currentHeaderCar = resolveHeaderCar(from: remoteCars)
        } catch {
            if userId != currentUserId {
                currentHeaderCar = nil
            }
        }
    }

    private func resolveHeaderCar(from cars: [Car]) -> Car? {
        guard !cars.isEmpty else { return nil }
        if let latestCarId = vm.posts.first?.carId,
           let matched = cars.first(where: { $0.id == latestCarId }) {
            return matched
        }
        return cars.first
    }
}

private struct CommunityProfileGridTile: View {
    let post: CommunityPost
    let photoURL: URL?
    var showsDeleteButton = false
    var onDelete: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let photoURL {
                    AsyncImage(url: photoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty:
                            ZStack {
                                Color.white.opacity(0.04)
                                ProgressView().tint(Color("EmpireMint"))
                            }
                        default:
                            tileFallback
                        }
                    }
                } else {
                    tileFallback
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 210)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.16), .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(profileStageLabel)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(stageColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(stageColor.opacity(0.15)))
                        .overlay(Capsule().stroke(stageColor.opacity(0.5), lineWidth: 1))

                    Text("\(post.horsepower) HP")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.cyan)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.cyan.opacity(0.15)))
                        .overlay(Capsule().stroke(Color.cyan.opacity(0.5), lineWidth: 1))

                    Spacer()

                    if post.likesCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                            Text("\(post.likesCount)")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color("EmpireMint"))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.carName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let makeModel {
                        Text(makeModel)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(1)
                    }
                }
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [stageColor.opacity(0.5), Color.white.opacity(0.08)],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .overlay(alignment: .topTrailing) {
            if showsDeleteButton {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(Color.red.opacity(0.9)))
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
        .shadow(color: Color.black.opacity(0.3), radius: 12, y: 8)
    }

    private var tileFallback: some View {
        ZStack {
            Color.white.opacity(0.05)
            Image(systemName: "car.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color("EmpireMint").opacity(0.35))
        }
    }

    private var makeModel: String? {
        let parts: [String] = [post.make, post.model].compactMap { value in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    private var profileStageLabel: String {
        if post.isJailbreak { return "JAILBREAK" }
        return post.stage == 0 ? "STOCK" : "STAGE \(post.stage)"
    }

    private var stageColor: Color {
        if post.isJailbreak { return .purple }
        switch post.stage {
        case 1: return Color("EmpireMint")
        case 2: return .yellow
        case 3: return .red
        default: return .gray
        }
    }
}

private struct ExpandedCommunityPostOverlay: View {
    let post: CommunityPost
    let currentUserId: String
    @ObservedObject var communityVM: CommunityViewModel
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.black.opacity(0.72))
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            LinearGradient(colors: [Color.black, Color.black.opacity(0.94)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 320)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                ExpandedCommunityPostCard(
                    post: post,
                    currentUserId: currentUserId,
                    communityVM: communityVM,
                    photoURL: communityVM.photoURL(for: post),
                    avatarURL: communityVM.avatarURL(for: post),
                    allowsProfileNavigation: false
                )
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .padding(.bottom, 24)
            }

            Button("Done", action: onClose)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("EmpireMint"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(Color("EmpireMint").opacity(0.35), lineWidth: 1))
                .padding(.leading, 16)
                .padding(.top, 14)
        }
    }
}

private struct ExpandedCommunityPostCard: View {
    let post: CommunityPost
    let currentUserId: String
    @ObservedObject var communityVM: CommunityViewModel
    let photoURL: URL?
    let avatarURL: URL?
    var allowsProfileNavigation = false

    @State private var showComments = false
    @State private var tilt: CGSize = .zero

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
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let photoURL {
                        AsyncImage(url: photoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .empty:
                                ZStack { Color.white.opacity(0.05); ProgressView().tint(Color("EmpireMint")) }
                            default:
                                ZStack {
                                    Color.white.opacity(0.05)
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Color("EmpireMint").opacity(0.35))
                                }
                            }
                        }
                    } else {
                        ZStack {
                            Color.white.opacity(0.05)
                            Image(systemName: "car.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color("EmpireMint").opacity(0.35))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 420)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.08), .black.opacity(0.18), .black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                HStack(spacing: 10) {
                    expandedAvatar
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.username ?? "Empire Driver")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(post.createdAt.relativeFormatted)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                .padding(16)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(post.carName)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let makeModelLine {
                        Text(makeModelLine)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    expandedChip(label: stageLabel.uppercased(), tint: stageAccent)
                    expandedChip(label: "\(post.horsepower) HP", tint: .cyan)
                    if let cls = post.vehicleClass {
                        expandedChip(label: cls.components(separatedBy: " - ").first ?? cls, tint: .white.opacity(0.7))
                    }
                }

                HStack(spacing: 10) {
                    expandedActionButton(
                        icon: post.isLiked ? "heart.fill" : "heart",
                        title: post.likesCount > 0 ? "\(post.likesCount)" : "Like",
                        tint: post.isLiked ? Color("EmpireMint") : .white
                    ) {
                        Task { await communityVM.toggleLike(postId: post.id) }
                    }

                    expandedActionButton(
                        icon: "bubble.left",
                        title: post.commentsCount > 0 ? "\(post.commentsCount)" : "Comment",
                        tint: .white
                    ) {
                        showComments = true
                    }

                    if let shareURL = URL(string: "https://empireontario.shop/cars/\(post.id.uuidString)") {
                        ShareLink(item: shareURL) {
                            expandedActionLabel(icon: "square.and.arrow.up", title: "Share", tint: .white)
                        }
                    }
                }

                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [stageAccent.opacity(0.75), Color.white.opacity(0.1), .clear],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: stageAccent.opacity(0.28), radius: 26, y: 14)
        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
        .rotation3DEffect(.degrees(Double(tilt.width) * 0.05), axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(Double(-tilt.height) * 0.05), axis: (x: 1, y: 0, z: 0))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let w = max(-20, min(20, value.translation.width))
                    let h = max(-20, min(20, value.translation.height))
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                        tilt = CGSize(width: w, height: h)
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        tilt = .zero
                    }
                }
        )
        .sheet(isPresented: $showComments) {
            CommentSheetView(post: post, currentUserId: currentUserId, communityVM: communityVM)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var expandedAvatar: some View {
        Group {
            if let avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            Image(systemName: "person.fill")
                .foregroundStyle(Color("EmpireMint"))
        }
    }

    private var stageLabel: String {
        if post.isJailbreak { return "Jailbreak" }
        return post.stage == 0 ? "Stock" : "Stage \(post.stage)"
    }

    private var makeModelLine: String? {
        let parts: [String] = [post.make, post.model].compactMap { value in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    private func expandedChip(label: String, tint: Color) -> some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.14)))
            .overlay(Capsule().stroke(tint.opacity(0.55), lineWidth: 1))
    }

    private func expandedActionButton(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            expandedActionLabel(icon: icon, title: title, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func expandedActionLabel(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
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
        .blendMode(.screen).allowsHitTesting(false)
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
