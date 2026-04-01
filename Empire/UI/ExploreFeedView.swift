import SwiftUI
import SwiftData
import Combine

struct ExploreFeedView: View {

    var communityCars: [Car] = []
    var userCars: [Car] = []
    @Binding var likedCommunity: Set<UUID>
    var onClose: () -> Void = {}

    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = CommunityViewModel()
    @StateObject private var socialStore = CommunitySocialStore()

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var showLikedOnly = false
    @State private var showSavedOnly = false
    @State private var selectedFeedMode: ExploreFeedMode = .forYou
    @State private var selectedStageFilter: ExploreStageFilter? = nil
    @State private var selectedVehicleClassFilter: VehicleClass? = nil
    @State private var expandedFilterMenu: ExpandedExploreFilterMenu? = nil
    @State private var filterMenuFrames: [ExpandedExploreFilterMenu: CGRect] = [:]
    @State private var showShareToFeed: Bool = false
    @State private var upcomingMeets: [Meet] = []
    @State private var selectedMeetFilterID: UUID? = nil

    private let meetsService = SupabaseMeetsService()

    private var currentUserId: String { UserDefaults.standard.string(forKey: "currentUserId") ?? "" }

    private var filteredPosts: [CommunityPost] {
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
                (!showLikedOnly || post.isLiked)
                    && (!showSavedOnly || socialStore.isSaved(post.id))
            }()

            let matchesStage: Bool = {
                guard let selectedStageFilter else { return true }
                return selectedStageFilter.matches(post: post)
            }()

            let matchesVehicleClass: Bool = {
                guard let selectedVehicleClassFilter else { return true }
                return VehicleClass.from(rawValue: post.vehicleClass) == selectedVehicleClassFilter
            }()

            let matchesMeet: Bool = {
                guard let selectedMeetFilterID else { return true }
                return post.linkedMeetId == selectedMeetFilterID
            }()

            return matchesSearch && matchesFilter && matchesStage && matchesVehicleClass && matchesMeet
        }
    }

    private var rankedPosts: [CommunityPost] {
        switch selectedFeedMode {
        case .forYou:
            return filteredPosts.sorted { forYouScore(for: $0) > forYouScore(for: $1) }
        case .trending:
            return filteredPosts.sorted { trendingScore(for: $0) > trendingScore(for: $1) }
        case .latest:
            return filteredPosts.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private var highlightedPost: CommunityPost? {
        rankedPosts.first
    }

    private var driverVehicleClasses: Set<VehicleClass> {
        Set(userCars.compactMap(\.vehicleClass))
    }

    private var driverStages: [Int] {
        userCars.map(\.stage)
    }

    private var currentChallenge: CommunityProgrammingChallenge {
        CommunityProgrammingChallenge.current()
    }

    private var challengePosts: [CommunityPost] {
        vm.posts.filter { $0.challengeID == currentChallenge.id }
    }

    private var meetLinkedPosts: [CommunityPost] {
        vm.posts.filter { $0.linkedMeetId != nil }
    }

    private var featuredVehicleClasses: [VehicleClass] {
        let counts = vm.posts.reduce(into: [VehicleClass: Int]()) { partial, post in
            guard let vehicleClass = VehicleClass.from(rawValue: post.vehicleClass) else { return }
            partial[vehicleClass, default: 0] += 1
        }
        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.displayName < rhs.key.displayName
            }
            return lhs.value > rhs.value
        }.map(\.key)
    }

    private var highlightedMeet: Meet? {
        if let selectedMeetFilterID {
            return upcomingMeets.first(where: { $0.id == selectedMeetFilterID })
        }
        let linkedIds = Set(meetLinkedPosts.compactMap(\.linkedMeetId))
        return upcomingMeets.first(where: { linkedIds.contains($0.id) }) ?? upcomingMeets.first
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
        .task {
            await socialStore.refreshFromBackend()
            await vm.refresh()
            await loadProgrammingSurfaces()
        }
        .onAppear {
            Task { await socialStore.refreshFromBackend() }
        }
        .onChange(of: currentUserId) { _, _ in
            Task { await socialStore.refreshFromBackend() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .empireCommunityDidPost)) { _ in
            Task {
                await vm.refresh()
                await loadProgrammingSurfaces()
            }
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
                Color.clear.frame(height: 8)

                filterChips
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                    .zIndex(3)

                feedDiscoveryPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .zIndex(1)

                ForEach(rankedPosts) { post in
                    feedPostCard(post)
                }

                if rankedPosts.isEmpty && !vm.isLoading {
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

                if !vm.hasMore && !rankedPosts.isEmpty {
                    Text("You've seen it all 🏁")
                        .font(.caption).foregroundStyle(.white.opacity(0.4))
                        .padding(.vertical, 20)
                }

                Color.clear.frame(height: 60)
            }
        }
        .refreshable {
            await vm.refresh()
            await loadProgrammingSurfaces()
        }
    }

    private func feedPostCard(_ post: CommunityPost) -> some View {
        HStack(spacing: 0) {
            FeedPostCard(
                post: post,
                currentUserId: currentUserId,
                communityVM: vm,
                avatarURL: vm.avatarURL(for: post),
                socialStore: socialStore
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .onAppear {
            if post.id == rankedPosts.last?.id {
                Task { await vm.loadMore() }
            }
        }
    }

    private var feedDiscoveryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Community Pulse")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)

                    Text(feedSummaryLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Image(systemName: selectedFeedMode.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(selectedFeedMode.label)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(selectedFeedMode.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(selectedFeedMode.accentColor.opacity(0.14)))
                .overlay(
                    Capsule()
                        .stroke(selectedFeedMode.accentColor.opacity(0.4), lineWidth: 1)
                )
            }

            HStack(spacing: 8) {
                ForEach(ExploreFeedMode.allCases, id: \.self) { mode in
                    FeedModeChip(
                        mode: mode,
                        isSelected: selectedFeedMode == mode
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedFeedMode = mode
                        }
                    }
                }
            }

            if let highlightedPost {
                Button {
                    if showLikedOnly {
                        showLikedOnly = false
                    }
                    if selectedFeedMode != .forYou {
                        selectedFeedMode = .forYou
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selectedFeedMode.heroTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(selectedFeedMode.accentColor)

                            Text(highlightedPost.carName)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(highlightReason(for: highlightedPost))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.66))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 12)

                        VStack(alignment: .trailing, spacing: 6) {
                            metricBadge(value: highlightedPost.likesCount, symbol: "heart.fill")
                            metricBadge(value: highlightedPost.commentsCount, symbol: "bubble.left.fill")
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.045))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [selectedFeedMode.accentColor.opacity(0.55), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: selectedFeedMode.accentColor.opacity(0.16), radius: 12, x: 0, y: 8)
    }

    private var feedSummaryLine: String {
        if vm.posts.isEmpty {
            return "Fresh builds, tuning updates, and conversations from Empire drivers."
        }

        switch selectedFeedMode {
        case .forYou:
            return "Fresh builds and the cars closest to your garage."
        case .trending:
            return "The hottest builds and busiest comment threads first."
        case .latest:
            return "The newest garage drops as soon as they land."
        }
    }

    private var programmingHighlightsRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                challengeSpotlightCard

                if let highlightedMeet {
                    meetLinkedSpotlight(meet: highlightedMeet)
                }

                ForEach(Array(featuredVehicleClasses.prefix(3)), id: \.self) { vehicleClass in
                    featuredClassCard(vehicleClass)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var challengeSpotlightCard: some View {
        HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(currentChallenge.accentColor.opacity(0.16))
                    Image(systemName: currentChallenge.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(currentChallenge.accentColor)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentChallenge.badgeTitle.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(currentChallenge.accentColor)
                    Text(currentChallenge.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(currentChallenge.composerPrompt)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(challengePosts.count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("joined")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        .frame(width: 214, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(currentChallenge.accentColor.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(currentChallenge.accentColor.opacity(0.32), lineWidth: 1)
        )
    }

    private func featuredClassCard(_ vehicleClass: VehicleClass) -> some View {
        let count = vm.posts.filter { VehicleClass.from(rawValue: $0.vehicleClass) == vehicleClass }.count
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedVehicleClassFilter = selectedVehicleClassFilter == vehicleClass ? nil : vehicleClass
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(vehicleClass.code)
                        .font(.caption.weight(.bold))
                    Text(vehicleClass.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(selectedVehicleClassFilter == vehicleClass ? vehicleClass.accentColor : .white.opacity(0.82))

                Text("\(count) build\(count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
            }
            .frame(width: 156, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selectedVehicleClassFilter == vehicleClass ? vehicleClass.accentColor.opacity(0.14) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selectedVehicleClassFilter == vehicleClass ? vehicleClass.accentColor.opacity(0.42) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func meetLinkedSpotlight(meet: Meet) -> some View {
        let linkedCount = vm.posts.filter { $0.linkedMeetId == meet.id }.count
        let isSelected = selectedMeetFilterID == meet.id

        return HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color("EmpireMint").opacity(0.14))
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("EmpireMint"))
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Meet-Linked Builds")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color("EmpireMint"))
                    Text(meet.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(meet.city) · \(meet.dateString)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(linkedCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(isSelected ? "filtering" : "linked")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        .frame(width: 204, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color("EmpireMint").opacity(0.08) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color("EmpireMint").opacity(0.28) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func metricBadge(value: Int, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
            Text("\(value)")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func highlightReason(for post: CommunityPost) -> String {
        switch selectedFeedMode {
        case .forYou:
            if hasAffinity(with: post) {
                return "Closest match for your garage."
            }
            return "Fresh, detailed, and already getting traction."
        case .trending:
            return "\(post.likesCount) likes and \(post.commentsCount) comments pushing it up."
        case .latest:
            return "Recently shared by \(post.username ?? "an Empire driver")."
        }
    }

    private func trendingScore(for post: CommunityPost) -> Double {
        let hoursOld = max(Date().timeIntervalSince(post.createdAt) / 3600, 0.0)
        let engagement = Double(post.likesCount * 3 + post.commentsCount * 5)
        let freshness = max(0.0, 72.0 - hoursOld) * 0.7
        let mediaBonus = Double(max(post.photoPaths.count, post.photoPath == nil ? 0 : 1)) * 2.5
        return engagement + freshness + mediaBonus
    }

    private func forYouScore(for post: CommunityPost) -> Double {
        trendingScore(for: post)
            + affinityScore(for: post)
            + captionQualityScore(for: post)
            + (post.isLiked ? 12 : 0)
    }

    private func affinityScore(for post: CommunityPost) -> Double {
        var score = 0.0

        if let postClass = VehicleClass.from(rawValue: post.vehicleClass),
           driverVehicleClasses.contains(postClass) {
            score += 18
        }

        if userCars.contains(where: {
            normalized($0.make) == normalized(post.make)
                && normalized($0.model) == normalized(post.model)
        }) {
            score += 16
        }

        if let closestStageDelta = driverStages.map({ abs($0 - post.stage) }).min() {
            score += max(0.0, 8.0 - Double(closestStageDelta * 2))
        }

        return score
    }

    private func captionQualityScore(for post: CommunityPost) -> Double {
        let trimmed = post.caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return 0 }
        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        return min(Double(wordCount), 18)
    }

    private func hasAffinity(with post: CommunityPost) -> Bool {
        affinityScore(for: post) >= 18
    }

    private func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    @MainActor
    private func loadProgrammingSurfaces() async {
        upcomingMeets = (try? await meetsService.fetchUpcomingMeets()) ?? []
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 8) {
                        FilterChip(
                            label: "Liked",
                            icon: "heart.fill",
                            accentColor: Color(red: 0.95, green: 0.3, blue: 0.45),
                            isSelected: showLikedOnly
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showLikedOnly.toggle()
                            }
                        }

                        FilterChip(
                            label: "Saved",
                            icon: "bookmark.fill",
                            accentColor: Color("EmpireMint"),
                            isSelected: showSavedOnly
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSavedOnly.toggle()
                            }
                        }

                        ExpandableFilterChip(
                            label: selectedStageFilter?.label ?? "Stage Levels",
                            icon: "slider.horizontal.3",
                            accentColor: selectedStageFilter?.accentColor ?? Color("EmpireMint"),
                            isSelected: selectedStageFilter != nil || expandedFilterMenu == .stageLevels,
                            isExpanded: expandedFilterMenu == .stageLevels
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                expandedFilterMenu = expandedFilterMenu == .stageLevels ? nil : .stageLevels
                            }
                        }
                        .background(filterMenuFrameReader(for: .stageLevels))

                        ExpandableFilterChip(
                            label: selectedVehicleClassFilter.map { "Class \($0.code)" } ?? "Vehicle Class",
                            icon: "car.fill",
                            accentColor: selectedVehicleClassFilter?.accentColor ?? Color("EmpireMint"),
                            isSelected: selectedVehicleClassFilter != nil || expandedFilterMenu == .vehicleClass,
                            isExpanded: expandedFilterMenu == .vehicleClass
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                expandedFilterMenu = expandedFilterMenu == .vehicleClass ? nil : .vehicleClass
                            }
                        }
                        .background(filterMenuFrameReader(for: .vehicleClass))

                        if hasActiveUtilityFilters {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    clearUtilityFilters()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Clear")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white.opacity(0.78))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.07)))
                                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }

                if let expandedFilterMenu,
                   let frame = filterMenuFrames[expandedFilterMenu] {
                    expandedMenuView(for: expandedFilterMenu)
                        .frame(width: menuWidth(for: expandedFilterMenu), alignment: .leading)
                        .offset(
                            x: clampedMenuX(
                                for: frame,
                                menu: expandedFilterMenu,
                                containerWidth: proxy.size.width
                            ),
                            y: frame.maxY + 8
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                        .zIndex(5)
                }
            }
            .coordinateSpace(name: "ExploreFilterChips")
            .onPreferenceChange(ExploreFilterMenuFramePreferenceKey.self) { filterMenuFrames = $0 }
        }
        .frame(height: 42)
    }

    private var hasActiveUtilityFilters: Bool {
        showLikedOnly || showSavedOnly || selectedStageFilter != nil || selectedVehicleClassFilter != nil || selectedMeetFilterID != nil
    }

    private func clearUtilityFilters() {
        showLikedOnly = false
        showSavedOnly = false
        selectedStageFilter = nil
        selectedVehicleClassFilter = nil
        selectedMeetFilterID = nil
        expandedFilterMenu = nil
    }

    private var expandedStageFilterList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ExploreStageFilter.allCases, id: \.self) { filter in
                expandedFilterRow(
                    label: filter.label,
                    accentColor: filter.accentColor,
                    isSelected: selectedStageFilter == filter
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedStageFilter = selectedStageFilter == filter ? nil : filter
                        expandedFilterMenu = nil
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("EmpireMint").opacity(0.14),
                            Color.white.opacity(0.05),
                            Color.black.opacity(0.34),
                            Color.black.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color("EmpireMint").opacity(0.18), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 8)
        .shadow(color: Color("EmpireMint").opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var expandedVehicleClassFilterList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(VehicleClass.allCases) { vehicleClass in
                expandedFilterRow(
                    label: "Class \(vehicleClass.code)",
                    accentColor: vehicleClass.accentColor,
                    isSelected: selectedVehicleClassFilter == vehicleClass
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedVehicleClassFilter = selectedVehicleClassFilter == vehicleClass ? nil : vehicleClass
                        expandedFilterMenu = nil
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("EmpireMint").opacity(0.14),
                            Color.white.opacity(0.05),
                            Color.black.opacity(0.34),
                            Color.black.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color("EmpireMint").opacity(0.18), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 8)
        .shadow(color: Color("EmpireMint").opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private func expandedFilterRow(label: String, accentColor: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(accentColor.opacity(isSelected ? 0.95 : 0.45))
                    .frame(width: 7, height: 7)

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? accentColor : .white.opacity(0.78))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.16) : Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? accentColor.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func expandedMenuView(for menu: ExpandedExploreFilterMenu) -> some View {
        Group {
            switch menu {
            case .stageLevels:
                expandedStageFilterList
            case .vehicleClass:
                expandedVehicleClassFilterList
            }
        }
    }

    private func menuWidth(for menu: ExpandedExploreFilterMenu) -> CGFloat {
        switch menu {
        case .stageLevels:
            return 148
        case .vehicleClass:
            return 136
        }
    }

    private func clampedMenuX(for frame: CGRect, menu: ExpandedExploreFilterMenu, containerWidth: CGFloat) -> CGFloat {
        let desiredX = frame.minX
        let maxX = max(16, containerWidth - menuWidth(for: menu) - 16)
        return min(max(desiredX, 16), maxX)
    }

    private func filterMenuFrameReader(for menu: ExpandedExploreFilterMenu) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ExploreFilterMenuFramePreferenceKey.self,
                value: [menu: proxy.frame(in: .named("ExploreFilterChips"))]
            )
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

enum ExploreFeedMode: CaseIterable {
    case forYou, trending, latest

    var label: String {
        switch self {
        case .forYou: return "For You"
        case .trending: return "Trending"
        case .latest: return "Latest"
        }
    }

    var icon: String {
        switch self {
        case .forYou: return "sparkles"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .latest: return "clock.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .forYou: return Color("EmpireMint")
        case .trending: return Color(red: 1.0, green: 0.52, blue: 0.22)
        case .latest: return Color.cyan
        }
    }

    var heroTitle: String {
        switch self {
        case .forYou: return "Best Match Right Now"
        case .trending: return "Moving Fast"
        case .latest: return "Fresh Off The Lift"
        }
    }
}

enum ExploreStageFilter: CaseIterable {
    case stock, stage1, stage2, stage3, stage4, stage5, maxOut, jailbreak

    var label: String {
        switch self {
        case .stock: return "Stock"
        case .stage1: return "Stage 1"
        case .stage2: return "Stage 2"
        case .stage3: return "Stage 3"
        case .stage4: return "Stage 4"
        case .stage5: return "Stage 5"
        case .maxOut: return "MAX"
        case .jailbreak: return "Jailbreak"
        }
    }

    var accentColor: Color {
        switch self {
        case .stock: return Color(white: 0.65)
        case .stage1: return Color("EmpireMint")
        case .stage2: return Color(red: 0.95, green: 0.78, blue: 0.1)
        case .stage3: return Color(red: 0.95, green: 0.28, blue: 0.22)
        case .stage4: return Color(red: 0.92, green: 0.20, blue: 0.16)
        case .stage5: return Color(red: 0.88, green: 0.16, blue: 0.28)
        case .maxOut: return Color(red: 0.76, green: 0.48, blue: 1.0)
        case .jailbreak: return Color(red: 0.65, green: 0.35, blue: 0.95)
        }
    }

    func matches(post: CommunityPost) -> Bool {
        switch self {
        case .stock: return post.stage == 0 && !post.isJailbreak
        case .stage1: return post.stage == 1 && !post.isJailbreak
        case .stage2: return post.stage == 2 && !post.isJailbreak
        case .stage3: return post.stage == 3 && !post.isJailbreak
        case .stage4: return post.stage == 4 && !post.isJailbreak
        case .stage5: return post.stage == 5 && !post.isJailbreak
        case .maxOut: return post.stage >= 6 && !post.isJailbreak
        case .jailbreak: return post.isJailbreak
        }
    }
}

private enum ExpandedExploreFilterMenu {
    case stageLevels
    case vehicleClass
}

private struct ExploreFilterMenuFramePreferenceKey: PreferenceKey {
    static var defaultValue: [ExpandedExploreFilterMenu: CGRect] = [:]

    static func reduce(value: inout [ExpandedExploreFilterMenu: CGRect], nextValue: () -> [ExpandedExploreFilterMenu: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let icon: String
    let accentColor: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(label).font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? selectedForeground : .white.opacity(0.65))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? accentColor.opacity(0.2) : Color.white.opacity(0.07)))
            .overlay(Capsule().stroke(isSelected ? accentColor.opacity(0.85) : Color.white.opacity(0.15),
                                      lineWidth: isSelected ? 1.5 : 1))
            .shadow(color: isSelected ? accentColor.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var selectedForeground: Color {
        accentColor
    }
}

private struct ExpandableFilterChip: View {
    let label: String
    let icon: String
    let accentColor: Color
    let isSelected: Bool
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.caption.weight(.semibold))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(isSelected ? accentColor : .white.opacity(0.65))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? accentColor.opacity(0.2) : Color.white.opacity(0.07)))
            .overlay(
                Capsule().stroke(
                    isSelected ? accentColor.opacity(0.85) : Color.white.opacity(0.15),
                    lineWidth: isSelected ? 1.5 : 1
                )
            )
            .shadow(color: isSelected ? accentColor.opacity(0.25) : .clear, radius: 6, x: 0, y: 3)
            .scaleEffect(isExpanded ? 1.03 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isExpanded)
        }
        .buttonStyle(.plain)
    }
}

private struct FeedModeChip: View {
    let mode: ExploreFeedMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(mode.label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? mode.accentColor : .white.opacity(0.72))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? mode.accentColor.opacity(0.18) : Color.white.opacity(0.05))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? mode.accentColor.opacity(0.75) : Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Individual post card

struct FeedPostCard: View {
    let post: CommunityPost
    let currentUserId: String
    @ObservedObject var communityVM: CommunityViewModel
    let avatarURL: URL?
    @ObservedObject var socialStore: CommunitySocialStore
    var allowsProfileNavigation = true

    @State private var showHeartBurst = false
    @State private var heartScale: CGFloat = 0.6
    @State private var heartOpacity: Double = 0.0
    @State private var showDeleteConfirm = false
    @State private var showComments = false
    @State private var showUserPosts = false
    @State private var currentPhotoIndex = 0
    @State private var photoDragOffset: CGFloat = 0

    private var isOwnPost: Bool {
        post.userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == currentUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    private var photoURLs: [URL] { communityVM.photoURLs(for: post) }

    private var stageAccent: Color {
        StageSystem.accentColor(for: post.stage, isJailbreak: post.isJailbreak)
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // Glass card base
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.085), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.32), radius: 12, x: 0, y: 8)

            // Hero photo
            Group {
                if !photoURLs.isEmpty {
                    if photoURLs.count == 1, let url = photoURLs.first {
                        GeometryReader { geo in
                            communityPhoto(url: url)
                                .frame(width: geo.size.width, height: 340)
                        }
                        .frame(height: 340)
                        .clipped()
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
                currentUserId: currentUserId,
                socialStore: socialStore
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Helpers

    private var stageLabel: String {
        StageSystem.displayLabel(for: post.stage, isJailbreak: post.isJailbreak)
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
                AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
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
        .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
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
                Text(post.createdAt.relativeFormatted)
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
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
                        .lineLimit(1)
                    if let buildCategory = BuildCategory.from(rawValue: post.buildCategory) {
                        BuildCategoryBadge(category: buildCategory, size: 18, materialOpacity: 0.14, strokeOpacity: 0.5)
                    }
                    if let vehicleClass = VehicleClass.from(rawValue: post.vehicleClass) {
                        Text(vehicleClass.code)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(vehicleClass.accentColor)
                            .shadow(color: vehicleClass.accentColor.opacity(0.9), radius: 8, x: 0, y: 0)
                            .shadow(color: vehicleClass.accentColor.opacity(0.45), radius: 16, x: 0, y: 0)
                    }
                }

                if let makeModelLine, !makeModelLine.isEmpty, makeModelLine != post.carName {
                    Text(makeModelLine)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .padding(.top, 10)

            if post.challengeID != nil || post.linkedMeetTitle != nil {
                postProgrammingBadges
            }

            HStack(spacing: 6) {
                Text(stageLabel.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(stageAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(stageAccent.opacity(0.15)))
                    .overlay(Capsule().stroke(stageAccent.opacity(0.7), lineWidth: 1))
                    .layoutPriority(2)

                Text("\(post.horsepower) WHP")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.6), lineWidth: 1))
                    .layoutPriority(2)

                Spacer(minLength: 4)

                Button { Task { await communityVM.toggleLike(postId: post.id) } } label: {
                    HStack(spacing: 5) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(post.isLiked ? Color("EmpireMint") : .white.opacity(0.85))
                        Text("\(post.likesCount)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    .font(.system(size: 15))
                    .frame(minWidth: 44)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.28)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button { showComments = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .foregroundStyle(.white.opacity(0.85))
                        Text("\(post.commentsCount)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    .font(.system(size: 15))
                    .frame(minWidth: 44)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.28)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    socialStore.toggleSaved(post.id)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: socialStore.isSaved(post.id) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(socialStore.isSaved(post.id) ? Color("EmpireMint") : .white.opacity(0.85))
                    }
                    .font(.system(size: 15))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.28)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)

                if let shareURL = URL(string: "https://empireontario.shop/cars/\(post.id.uuidString)") {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(7)
                            .background(Circle().fill(Color.black.opacity(0.28)))
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                }
            }

            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
            }
        }
    }

    private var postProgrammingBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let challenge = post.challengeID.flatMap(CommunityProgrammingChallenge.init(rawValue:)) {
                    programmingBadge(
                        icon: challenge.icon,
                        label: challenge.title,
                        tint: challenge.accentColor
                    )
                }

                if let linkedMeetTitle = post.linkedMeetTitle {
                    programmingBadge(
                        icon: "calendar",
                        label: linkedMeetTitle,
                        tint: Color("EmpireMint")
                    )
                }
            }
        }
    }

    private func programmingBadge(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(label)
                .lineLimit(1)
        }
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 1))
    }

    private func communityPhoto(url: URL) -> some View {
        AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
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
    @ObservedObject var socialStore: CommunitySocialStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: CommunityViewModel
    @State private var garageCars: [Car] = []
    @State private var isGarageLoading = false
    @State private var centeredGarageEntryID: UUID? = nil
    @State private var garageSpecsEntry: CommunityGarageEntry? = nil
    @State private var garageModsEntry: CommunityGarageEntry? = nil
    @State private var pendingDeletePost: CommunityPost? = nil
    @State private var isDeleteMode = false

    private let carsService = SupabaseCarsService()

    init(userId: String, username: String?, avatarURL: URL?, currentUserId: String, socialStore: CommunitySocialStore) {
        self.userId = userId
        self.username = username
        self.avatarURL = avatarURL
        self.currentUserId = currentUserId
        self.socialStore = socialStore
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
                        VStack(spacing: 12) {
                            profileHeader
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                            garageSection
                                .padding(.horizontal, 16)

                            postsSection
                                .padding(.horizontal, 16)

                            Color.clear.frame(height: 32)
                        }
                    }
                    .refreshable {
                        await socialStore.refreshFollowerCount(for: userId)
                        await vm.refresh()
                        await refreshGarage()
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
            await socialStore.refreshFromBackend()
            await socialStore.refreshFollowerCount(for: userId)
            await vm.refresh()
            await refreshGarage()
        }
        .onChange(of: vm.posts.map(\.id)) { _, _ in
            Task { await refreshGarage() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .empireCommunityDidPost)) { _ in
            Task {
                await vm.refresh()
                await refreshGarage()
                if vm.posts.isEmpty {
                    isDeleteMode = false
                }
            }
        }
        .sheet(item: $garageSpecsEntry) { entry in
            SpecsListView(specs: entry.car.specs)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $garageModsEntry) { entry in
            ModsListView(mods: entry.car.mods)
                .preferredColorScheme(.dark)
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                avatar

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("@\(displayHandle)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)

                    HStack(spacing: 6) {
                        reputationBadge
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 6)

                if !isOwnProfile {
                    followButton
                }
            }

            HStack(spacing: 6) {
                profileMetric(value: "\(vm.totalPostsCount)", label: "Posts")
                profileMetric(value: "\(garageEntries.count)", label: "Garage")
                profileMetric(value: "\(socialStore.followerCount(for: userId))", label: "Followers")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
        .shadow(color: Color.black.opacity(0.16), radius: 12, y: 6)
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
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: Color("EmpireMint").opacity(0.14), radius: 7, y: 3)
    }

    private var garageSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            simpleSectionHeader(title: "Garage", count: garageEntries.count)

            if isGarageLoading && garageEntries.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Color("EmpireMint"))
                    Text("Loading garage…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            } else if garageEntries.isEmpty {
                emptyGarageCard
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(garageEntries) { entry in
                            CommunityGarageCard(
                                entry: entry,
                                isCentered: centeredGarageEntryID == entry.id,
                                onMods: { if entry.hasFullDetails { garageModsEntry = entry } },
                                onSpecs: { if entry.hasFullDetails { garageSpecsEntry = entry } }
                            )
                            .frame(width: 194)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.955)
                                    .rotation3DEffect(.degrees(phase.value * -7), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
                                    .opacity(phase.isIdentity ? 1.0 : 0.88)
                            }
                            .id(entry.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $centeredGarageEntryID)
                .contentMargins(.horizontal, 10, for: .scrollContent)
                .safeAreaPadding(.horizontal, 2)
            }
        }
        .onAppear {
            if centeredGarageEntryID == nil {
                centeredGarageEntryID = garageEntries.first?.id
            }
        }
        .onChange(of: garageEntries.map(\.id)) { _, ids in
            guard !ids.isEmpty else {
                centeredGarageEntryID = nil
                return
            }
            if let centeredGarageEntryID, ids.contains(centeredGarageEntryID) {
                return
            }
            self.centeredGarageEntryID = ids.first
        }
    }

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            simpleSectionHeader(title: "Posts", count: vm.totalPostsCount)

            if let errorMessage = vm.errorMessage, vm.posts.isEmpty {
                compactProfileMessageCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "Couldn't load posts",
                    subtitle: errorMessage
                ) {
                    Button("Retry") {
                        Task { await vm.refresh() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("EmpireMint"))
                }
            } else if vm.posts.isEmpty {
                compactProfileMessageCard(
                    icon: "sparkles.rectangle.stack",
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 9) {
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

                if vm.isLoadingMore {
                    ProgressView()
                        .tint(Color("EmpireMint"))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var emptyGarageCard: some View {
        Text("No garage builds yet")
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var garageEntries: [CommunityGarageEntry] {
        if !garageCars.isEmpty {
            return garageCars.map { CommunityGarageEntry(car: $0, photoURL: nil, hasFullDetails: true) }
        }

        var seenKeys = Set<String>()
        var entries: [CommunityGarageEntry] = []

        for post in vm.posts {
            let key = post.carId?.uuidString ?? "\(post.userId)-\(post.carName.lowercased())-\((post.make ?? "").lowercased())-\((post.model ?? "").lowercased())"
            guard seenKeys.insert(key).inserted else { continue }

            let synthesized = Car(
                id: post.carId ?? post.id,
                name: post.carName,
                description: [post.make, post.model].compactMap { $0 }.joined(separator: " "),
                make: post.make,
                model: post.model,
                imageName: "car0",
                photoFileName: nil,
                horsepower: post.horsepower,
                stage: post.stage,
                specs: [],
                mods: [],
                isJailbreak: post.isJailbreak,
                vehicleClass: VehicleClass.from(rawValue: post.vehicleClass),
                buildCategory: BuildCategory.from(rawValue: post.buildCategory)
            )

            entries.append(
                CommunityGarageEntry(
                    car: synthesized,
                    photoURL: vm.photoURL(for: post),
                    hasFullDetails: false
                )
            )
        }

        return entries
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
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(minWidth: 48)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var followButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await socialStore.toggleFollow(userId) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: socialStore.isFollowing(userId) ? "checkmark.circle.fill" : "person.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
                Text(socialStore.isFollowing(userId) ? "Following" : "Follow")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .foregroundStyle(socialStore.isFollowing(userId) ? Color("EmpireMint") : .white.opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(socialStore.isFollowing(userId) ? Color("EmpireMint").opacity(0.16) : Color.white.opacity(0.05)))
            .overlay(Capsule().stroke(socialStore.isFollowing(userId) ? Color("EmpireMint").opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var reputationBadge: some View {
        let reputation = socialStore.reputation(
            for: userId,
            username: username,
            posts: vm.posts,
            garageCount: garageEntries.count
        )
        return HStack(spacing: 6) {
            Image(systemName: reputation.symbol)
                .font(.system(size: 9, weight: .bold))
            Text(reputation.title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(reputation.tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(reputation.tint.opacity(0.14)))
        .overlay(Capsule().stroke(reputation.tint.opacity(0.36), lineWidth: 1))
    }

    private func simpleSectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 10)
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color("EmpireMint"))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color("EmpireMint").opacity(0.14)))
                .overlay(Capsule().stroke(Color("EmpireMint").opacity(0.35), lineWidth: 1))
        }
    }

    private func compactProfileMessageCard<Accessory: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color("EmpireMint").opacity(0.55))
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
            accessory()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func compactProfileMessageCard(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        compactProfileMessageCard(icon: icon, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }

    @MainActor
    private func refreshGarage() async {
        isGarageLoading = true

        if userId == currentUserId {
            let localCars = LocalStore.shared.fetchCars(context: modelContext, userKey: userId)
            garageCars = localCars
            if !localCars.isEmpty {
                isGarageLoading = false
                return
            }
        }

        do {
            let remoteCars = try await carsService.fetchCars(for: userId)
            garageCars = remoteCars
        } catch {
            if userId != currentUserId {
                garageCars = []
            }
        }

        isGarageLoading = false
    }
}

private struct CommunityProfileGridTile: View {
    let post: CommunityPost
    let photoURL: URL?
    var showsDeleteButton = false
    var onDelete: (() -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
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
                    }
                    else {
                        tileFallback
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.16), .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .topTrailing) {
                    if !showsDeleteButton {
                        VStack(alignment: .trailing, spacing: 6) {
                            if let buildCategory = BuildCategory.from(rawValue: post.buildCategory) {
                                BuildCategoryBadge(category: buildCategory, size: 18, materialOpacity: 0.14, strokeOpacity: 0.45)
                            }

                            HStack(spacing: 3) {
                                Image(systemName: "heart.fill")
                                Text("\(post.likesCount)")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color("EmpireMint"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.24)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                        }
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center, spacing: 5) {
                        Text(profileStageLabel)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)
                            .foregroundStyle(stageColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(stageColor.opacity(0.15)))
                            .overlay(Capsule().stroke(stageColor.opacity(0.5), lineWidth: 1))
                            .layoutPriority(2)

                        Text("\(post.horsepower) WHP")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)
                            .foregroundStyle(Color.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.cyan.opacity(0.15)))
                            .overlay(Capsule().stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                            .layoutPriority(1)
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
                .padding(9)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
            .shadow(color: Color.black.opacity(0.28), radius: 10, y: 7)
        }
        .frame(height: 184)
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
        StageSystem.displayLabel(for: post.stage, isJailbreak: post.isJailbreak).uppercased()
    }

    private var stageColor: Color {
        StageSystem.accentColor(for: post.stage, isJailbreak: post.isJailbreak)
    }
}

private struct CommunityGarageEntry: Identifiable {
    let car: Car
    let photoURL: URL?
    let hasFullDetails: Bool

    var id: UUID { car.id }
}

private struct CommunityGarageCard: View {
    let entry: CommunityGarageEntry
    let isCentered: Bool
    var onMods: () -> Void
    var onSpecs: () -> Void

    private var car: Car { entry.car }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                garageImage
                    .frame(maxWidth: .infinity)
                    .frame(height: 118)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.18), .black.opacity(0.74)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

            }

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(car.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if let buildCategory = car.buildCategory {
                            BuildCategoryBadge(category: buildCategory, size: 16, materialOpacity: 0.14, strokeOpacity: 0.5)
                        }
                    }

                    if let makeModelLine {
                        Text(makeModelLine)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    if let vehicleClass = car.vehicleClass {
                        garageChip(label: vehicleClass.code, tint: vehicleClass.accentColor)
                    }
                    garageChip(
                        label: StageSystem.displayLabel(for: car.stage, isJailbreak: car.isJailbreak).uppercased(),
                        tint: StageSystem.accentColor(for: car.stage, isJailbreak: car.isJailbreak)
                    )
                    garageChip(label: "\(car.horsepower) WHP", tint: .cyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 12)

            HStack(spacing: 0) {
                garageMenuButton(icon: "wrench.and.screwdriver", label: "Mods", tint: entry.hasFullDetails ? .white.opacity(0.78) : .white.opacity(0.28), isDisabled: !entry.hasFullDetails, action: onMods)
                garageDivider
                garageMenuButton(icon: "dial.low", label: "Specs", tint: entry.hasFullDetails ? .white.opacity(0.78) : .white.opacity(0.28), isDisabled: !entry.hasFullDetails, action: onSpecs)
            }
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isCentered ? 0.07 : 0.045),
                            Color.white.opacity(0.018),
                            Color.black.opacity(isCentered ? 0.08 : 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.05), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
                .overlay(
                    RadialGradient(
                        colors: [Color("EmpireMint").opacity(isCentered ? 0.18 : 0.08), .clear],
                        center: .bottomLeading,
                        startRadius: 10,
                        endRadius: 180
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [StageSystem.accentColor(for: car.stage, isJailbreak: car.isJailbreak).opacity(isCentered ? 0.62 : 0.42), Color.white.opacity(isCentered ? 0.14 : 0.08)],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    lineWidth: isCentered ? 1.4 : 1.1
                )
        )
        .shadow(color: Color("EmpireMint").opacity(isCentered ? 0.2 : 0.08), radius: isCentered ? 18 : 12, y: isCentered ? 10 : 7)
        .shadow(color: .black.opacity(isCentered ? 0.34 : 0.24), radius: isCentered ? 16 : 10, y: isCentered ? 10 : 6)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var garageImage: some View {
        if let photoURL = entry.photoURL {
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ZStack { Color.white.opacity(0.04); ProgressView().tint(Color("EmpireMint")) }
                default:
                    fallbackGarageImage
                }
            }
        } else if let fileName = car.photoFileName,
                  let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                  let data = try? Data(contentsOf: dir.appendingPathComponent(fileName)),
                  let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            fallbackGarageImage
        }
    }

    private var fallbackGarageImage: some View {
        Image(car.imageName)
            .resizable()
            .scaledToFill()
    }

    private var makeModelLine: String? {
        let parts = [car.make, car.model].compactMap { value -> String? in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func garageChip(label: String, tint: Color) -> some View {
        Text(label)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.15)))
            .overlay(Capsule().stroke(tint.opacity(0.52), lineWidth: 1))
    }

    private var garageDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 34)
    }

    private func garageMenuButton(
        icon: String,
        label: String,
        tint: Color,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct ExpandedCommunityPostOverlay: View {
    let post: CommunityPost
    let currentUserId: String
    @ObservedObject var communityVM: CommunityViewModel
    @ObservedObject var socialStore: CommunitySocialStore
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
                    socialStore: socialStore,
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
    @ObservedObject var socialStore: CommunitySocialStore
    let photoURL: URL?
    let avatarURL: URL?
    var allowsProfileNavigation = false

    @State private var showComments = false

    private var stageAccent: Color {
        StageSystem.accentColor(for: post.stage, isJailbreak: post.isJailbreak)
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
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(post.carName)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if let buildCategory = BuildCategory.from(rawValue: post.buildCategory) {
                            BuildCategoryBadge(category: buildCategory, size: 22, materialOpacity: 0.14, strokeOpacity: 0.55)
                        }
                    }

                    if let makeModelLine {
                        Text(makeModelLine)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    expandedChip(label: stageLabel.uppercased(), tint: stageAccent)
                    expandedChip(label: "\(post.horsepower) WHP", tint: .cyan)
                    if let cls = VehicleClass.from(rawValue: post.vehicleClass) {
                        expandedChip(label: "\(cls.code) \(cls.displayName)", tint: cls.accentColor)
                    }
                }

                HStack(spacing: 10) {
                    expandedActionButton(
                        icon: post.isLiked ? "heart.fill" : "heart",
                        title: "\(post.likesCount)",
                        tint: post.isLiked ? Color("EmpireMint") : .white
                    ) {
                        Task { await communityVM.toggleLike(postId: post.id) }
                    }

                    expandedActionButton(
                        icon: "bubble.left",
                        title: "\(post.commentsCount)",
                        tint: .white
                    ) {
                        showComments = true
                    }

                    expandedActionButton(
                        icon: socialStore.isSaved(post.id) ? "bookmark.fill" : "bookmark",
                        title: socialStore.isSaved(post.id) ? "Saved" : "Save",
                        tint: socialStore.isSaved(post.id) ? Color("EmpireMint") : .white
                    ) {
                        socialStore.toggleSaved(post.id)
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
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.085), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
        .shadow(color: .black.opacity(0.32), radius: 14, y: 8)
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
        StageSystem.displayLabel(for: post.stage, isJailbreak: post.isJailbreak)
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
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.14)))
            .overlay(Capsule().stroke(tint.opacity(0.55), lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
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
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

@MainActor
final class CommunitySocialStore: ObservableObject {
    @Published private(set) var followedUserIDs: Set<String> = []
    @Published private(set) var savedPostIDs: Set<UUID> = []
    @Published private(set) var followerCounts: [String: Int] = [:]

    private let communityService = SupabaseCommunityService()

    private var currentUserKey: String {
        UserDefaults.standard.string(forKey: "currentUserId")?.lowercased() ?? "guest"
    }

    private var followedUsersKey: String { "community_followed_users_\(currentUserKey)" }
    private var savedPostsKey: String { "community_saved_posts_\(currentUserKey)" }
    private let followerCountsKey = "community_follower_counts"

    init() {
        reload()
    }

    func reload() {
        followedUserIDs = Set(
            (UserDefaults.standard.stringArray(forKey: followedUsersKey) ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
        savedPostIDs = Set(
            (UserDefaults.standard.stringArray(forKey: savedPostsKey) ?? [])
                .compactMap(UUID.init(uuidString:))
        )
        followerCounts = (UserDefaults.standard.dictionary(forKey: followerCountsKey) ?? [:]).reduce(into: [:]) { partial, item in
            let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return }

            if let count = item.value as? Int {
                partial[key] = max(0, count)
            } else if let count = item.value as? NSNumber {
                partial[key] = max(0, count.intValue)
            }
        }
    }

    func isFollowing(_ userId: String) -> Bool {
        followedUserIDs.contains(normalized(userId))
    }

    func refreshFromBackend() async {
        reload()
        guard currentUserKey != "guest" else { return }
        do {
            let remoteIDs = try await communityService.fetchFollowedUserIDs(currentUserId: currentUserKey)
            followedUserIDs = remoteIDs
            UserDefaults.standard.set(Array(remoteIDs).sorted(), forKey: followedUsersKey)
        } catch {
            // Keep cached local state when backend fetch fails.
        }
    }

    func refreshFollowerCount(for userId: String) async {
        let key = normalized(userId)
        guard !key.isEmpty else { return }

        do {
            let remoteCount = try await communityService.fetchFollowerCount(userId: key)
            followerCounts[key] = remoteCount
            persistFollowerCounts()
        } catch {
            // Keep cached local state when backend fetch fails.
        }
    }

    func toggleFollow(_ userId: String) async {
        let key = normalized(userId)
        guard !key.isEmpty else { return }

        let wasFollowing = followedUserIDs.contains(key)
        let previousFollowerCount = followerCounts[key] ?? 0

        if wasFollowing {
            followedUserIDs.remove(key)
            followerCounts[key] = max(0, previousFollowerCount - 1)
        } else {
            followedUserIDs.insert(key)
            followerCounts[key] = previousFollowerCount + 1
        }
        UserDefaults.standard.set(Array(followedUserIDs).sorted(), forKey: followedUsersKey)
        persistFollowerCounts()

        guard currentUserKey != "guest" else { return }

        do {
            if wasFollowing {
                try await communityService.unfollowUser(currentUserId: currentUserKey, targetUserId: key)
            } else {
                try await communityService.followUser(currentUserId: currentUserKey, targetUserId: key)
            }
        } catch {
            if wasFollowing {
                followedUserIDs.insert(key)
            } else {
                followedUserIDs.remove(key)
            }
            followerCounts[key] = previousFollowerCount
            UserDefaults.standard.set(Array(followedUserIDs).sorted(), forKey: followedUsersKey)
            persistFollowerCounts()
        }
    }

    func followerCount(for userId: String) -> Int {
        followerCounts[normalized(userId)] ?? 0
    }

    func isSaved(_ postId: UUID) -> Bool {
        savedPostIDs.contains(postId)
    }

    func toggleSaved(_ postId: UUID) {
        if savedPostIDs.contains(postId) {
            savedPostIDs.remove(postId)
        } else {
            savedPostIDs.insert(postId)
        }
        UserDefaults.standard.set(savedPostIDs.map(\.uuidString).sorted(), forKey: savedPostsKey)
    }

    func reputation(for userId: String, username: String?, posts: [CommunityPost], garageCount: Int) -> CommunityReputation {
        let followerBoost = followerCount(for: userId) * 10
        let likes = posts.reduce(0) { $0 + $1.likesCount }
        let comments = posts.reduce(0) { $0 + $1.commentsCount }
        let score = (posts.count * 16) + (garageCount * 14) + likes + (comments * 2) + followerBoost

        switch score {
        case 90...:
            return CommunityReputation(title: "Empire Icon", symbol: "sparkles", tint: Color("EmpireMint"))
        case 55...:
            return CommunityReputation(title: "Respected Build", symbol: "bolt.fill", tint: .cyan)
        case 25...:
            return CommunityReputation(title: "On The Rise", symbol: "arrow.up.right.circle.fill", tint: Color(red: 0.96, green: 0.58, blue: 0.22))
        default:
            return CommunityReputation(title: posts.isEmpty && garageCount == 0 ? "New Driver" : "Fresh Build", symbol: "circle.hexagongrid.fill", tint: Color.white.opacity(0.8))
        }
    }

    private func normalized(_ userId: String) -> String {
        userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func persistFollowerCounts() {
        UserDefaults.standard.set(followerCounts, forKey: followerCountsKey)
    }
}

struct CommunityReputation {
    let title: String
    let symbol: String
    let tint: Color
}

private func stageTint(for stage: Int) -> Color {
    StageSystem.accentColor(for: stage, isJailbreak: false)
}
