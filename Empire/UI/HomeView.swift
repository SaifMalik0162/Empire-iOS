import SwiftUI
import UIKit
import SwiftData
import Combine
import UserNotifications

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var communityInboxVM: CommunityInboxViewModel

    // MARK: - Meets Data
    @State private var meets: [Meet] = []
    @State private var garageSnapshot: [Car] = []
    @State private var showSettings: Bool = false
    @State private var showCommunityInbox: Bool = false
    @State private var isLoadingMeets = false
    @State private var meetsError: String? = nil
    @State private var featuredUserCarPhotoData: Data? = nil
    @State private var featuredMerch: [MerchItem] = []
    @State private var isRefreshingFeaturedMerch = false
    @State private var lastFeaturedMerchRefreshAt: Date? = nil
    @State private var lastMeetsRefreshAt: Date? = nil
    @State private var lastFeaturedCardsRefreshAt: Date? = nil

    @StateObject private var communityVM = CommunityViewModel()
    @StateObject private var socialStore = CommunitySocialStore()

    // MARK: - Data Sources
    private let communityCars: [Car] = [
        Car(name: "Honda Prelude BB2", description: "@officialtobysemple — Clean BB2 build", imageName: "prelude_bb2", horsepower: 450, stage: 3),
        Car(name: "Civic Si Coupe", description: "@fg2_corey — FG2 Si coupe", imageName: "civic_si_fg2", horsepower: 220, stage: 2),
        Car(name: "1968 Mustang", description: "347 Stroker V8", imageName: "68_blaze", horsepower: 350, stage: 2)
    ]

    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
    }

    private var featuredCards: [HomeFeaturedCardItem] {
        var cards: [HomeFeaturedCardItem] = []

        if let featuredUserCarPhotoData, let firstCar = garageSnapshot.first {
            cards.append(
                HomeFeaturedCardItem(
                    id: "garage-\(firstCar.id.uuidString.lowercased())",
                    title: firstCar.name,
                    subtitle: "Your build",
                    badge: "Garage",
                    localImageData: featuredUserCarPhotoData
                )
            )
        }

        let vehicleClasses = Set(garageSnapshot.compactMap(\.vehicleClass?.rawValue))
        let buildCategories = Set(garageSnapshot.compactMap(\.buildCategory?.rawValue))
        let userMakes = Set(garageSnapshot.compactMap { $0.make?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let normalizedCurrentUser = currentUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let rankedPosts = communityVM.posts.compactMap { post -> HomeFeaturedCardItem? in
            let normalizedAuthor = post.userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard normalizedAuthor != normalizedCurrentUser else { return nil }

            var score = 0
            var badge = "Featured"

            if socialStore.isFollowing(post.userId) {
                score += 40
                badge = "Following"
            }
            if let vehicleClass = post.vehicleClass, vehicleClasses.contains(vehicleClass) {
                score += 28
                badge = "Your Class"
            }
            if let buildCategory = post.buildCategory, buildCategories.contains(buildCategory) {
                score += 22
                badge = "Your Style"
            }
            if let make = post.make?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               userMakes.contains(make) {
                score += 18
                badge = "Same Platform"
            }

            score += min(post.likesCount, 16)
            score += min(post.commentsCount * 2, 14)

            guard score > 0 else { return nil }

            let username = post.username?.trimmingCharacters(in: .whitespacesAndNewlines)
            return HomeFeaturedCardItem(
                id: "post-\(post.id.uuidString.lowercased())",
                title: post.carName,
                subtitle: username.map { "@\($0)" } ?? "Empire Driver",
                badge: badge,
                remoteImageURL: communityVM.photoURL(for: post, variant: .feed),
                fallbackImageName: fallbackAssetName(for: post),
                score: score,
                authorKey: normalizedAuthor
            )
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.title < rhs.title
        }

        var selectedPostCards: [HomeFeaturedCardItem] = []
        var usedAuthors: Set<String> = []
        var usedBadges: Set<String> = []

        if let samePlatformCard = rankedPosts.first(where: { $0.badge == "Same Platform" }) {
            selectedPostCards.append(samePlatformCard)
            if let authorKey = samePlatformCard.authorKey {
                usedAuthors.insert(authorKey)
            }
            usedBadges.insert(samePlatformCard.badge)
        }

        let prioritizedVariety = rankedPosts.filter { card in
            guard selectedPostCards.count < 3 else { return false }
            if let authorKey = card.authorKey, usedAuthors.contains(authorKey) {
                return false
            }
            if usedBadges.contains(card.badge) {
                return false
            }
            return true
        }

        for card in prioritizedVariety {
            guard selectedPostCards.count < 3 else { break }
            selectedPostCards.append(card)
            if let authorKey = card.authorKey {
                usedAuthors.insert(authorKey)
            }
            usedBadges.insert(card.badge)
        }

        let fallbackVariety = rankedPosts.filter { card in
            guard selectedPostCards.count < 3 else { return false }
            if card.badge == "Same Platform", usedBadges.contains("Same Platform") {
                return false
            }
            if let authorKey = card.authorKey, usedAuthors.contains(authorKey) {
                return false
            }
            return !selectedPostCards.contains(where: { $0.title == card.title && $0.subtitle == card.subtitle })
        }

        for card in fallbackVariety {
            guard selectedPostCards.count < 3 else { break }
            selectedPostCards.append(card)
            if let authorKey = card.authorKey {
                usedAuthors.insert(authorKey)
            }
        }

        cards.append(contentsOf: selectedPostCards)

        if cards.count < 4 {
            for car in communityCars {
                guard cards.count < 4 else { break }
                let duplicate = cards.contains { $0.title == car.name }
                if duplicate { continue }
                cards.append(
                    HomeFeaturedCardItem(
                        id: "fallback-\(car.imageName)",
                        title: car.name,
                        subtitle: car.description,
                        badge: "Spotlight",
                        fallbackImageName: car.imageName
                    )
                )
            }
        }

        return cards
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

                // Subtle top glow
                RadialGradient(colors: [Color("EmpireMint").opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                GeometryReader { geo in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            HomeHeader(
                                showSettings: $showSettings,
                                showCommunityInbox: $showCommunityInbox,
                                communityUnreadCount: communityInboxVM.unreadCount
                            )
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            // MARK: - Upcoming Meets (Compact & Sleek)
                            GlassCard(height: nil) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Upcoming Meets")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Spacer()
                                        NavigationLink {
                                            MeetsView()
                                        } label: {
                                            Text("See All")
                                                .font(.subheadline)
                                                .foregroundColor(Color("EmpireMint"))
                                        }
                                    }

                                    if isLoadingMeets {
                                        HStack(spacing: 10) {
                                            ProgressView().tint(Color("EmpireMint"))
                                            Text("Loading...")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        .padding(.vertical, 8)
                                    } else if let err = meetsError {
                                        Text(err)
                                            .font(.caption)
                                            .foregroundColor(.red.opacity(0.8))
                                    } else if meets.isEmpty {
                                        Text("No upcoming meets")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    } else {
                                        VStack(spacing: 10) {
                                            ForEach(Array(meets.prefix(1))) { meet in
                                                HStack(spacing: 12) {
                                                    // Accent orb
                                                    ZStack {
                                                        Circle()
                                                            .fill(
                                                                RadialGradient(colors: [Color("EmpireMint").opacity(0.9), .clear], center: .center, startRadius: 2, endRadius: 26)
                                                            )
                                                            .frame(width: 42, height: 42)
                                                            .overlay(
                                                                Circle()
                                                                    .stroke(LinearGradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                                                            )
                                                            .shadow(color: Color("EmpireMint").opacity(0.35), radius: 8, x: 0, y: 4)
                                                    }

                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(meet.title)
                                                            .font(.subheadline.weight(.semibold))
                                                            .foregroundColor(.white)
                                                            .lineLimit(1)
                                                        HStack(spacing: 6) {
                                                            Image(systemName: "mappin.and.ellipse")
                                                                .imageScale(.small)
                                                                .foregroundStyle(Color("EmpireMint").opacity(0.9))
                                                            Text("\(meet.city) · \(meet.dateString)")
                                                                .font(.caption2)
                                                                .foregroundColor(.white.opacity(0.7))
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .foregroundColor(Color("EmpireMint").opacity(0.9))
                                                }
                                                .padding(10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(Color.white.opacity(0.04))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 14)
                                                                .stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                                        )
                                                )
                                            }
                                        }
                                    }
                                }
                                .padding(14)
                                .onAppear { loadHomeMeets() }
                            }

                            // MARK: - Featured Cars Carousel
                            HStack {
                                Text("Featured Cars")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                NavigationLink {
                                    CarsView()
                                } label: {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundColor(Color("EmpireMint"))
                                }
                            }
                            .padding(.horizontal, 16)

                            GlassCard(height: 200) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 20) {
                                        ForEach(featuredCards) { card in
                                            NavigationLink {
                                                CarsView()
                                            } label: {
                                                HomeFeaturedCard(card: card)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxHeight: .infinity, alignment: .center)
                                    .padding(.leading, 16)
                                    .padding(.trailing, 60)
                                    .padding(.vertical, 10)
                                }
                            }
                            .padding(.horizontal, 16)

                            Text("Swipe →")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.leading, 24)

                            // MARK: - Empire Merch Preview
                            GlassCard(height: 140) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Empire Merch")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Spacer()
                                        NavigationLink {
                                            MerchView()
                                        } label: {
                                            Text("See All")
                                                .font(.subheadline)
                                                .foregroundColor(Color("EmpireMint"))
                                        }
                                    }
                                    Text("Shop the latest drops")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))

                                    HStack(spacing: 16) {
                                        ForEach(Array(featuredMerch.prefix(3)).indices, id: \.self) { i in
                                            let item = featuredMerch[i]
                                            NavigationLink {
                                                ProductDetailView(item: item, related: relatedMerch(for: item))
                                            } label: {
                                                ZStack {
                                                    // Card base
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .fill(.ultraThinMaterial)
                                                        .frame(width: 100, height: 100)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 18)
                                                                .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                                                .blendMode(.screen)
                                                        )
                                                        .shadow(color: Color("EmpireMint").opacity(0.25), radius: 8, y: 3)

                                                    // Full-bleed merch image
                                                    Image(item.imageName)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 100, height: 100)
                                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                                        .opacity(0.9)
                                                        .overlay(
                                                            LinearGradient(
                                                                colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                                                                startPoint: .top,
                                                                endPoint: .bottom
                                                            )
                                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                                        )
                                                        .overlay(
                                                            LinearGradient(
                                                                gradient: Gradient(stops: [
                                                                    .init(color: .clear, location: 0.0),
                                                                    .init(color: .white.opacity(0.18), location: 0.5),
                                                                    .init(color: .clear, location: 1.0)
                                                                ]),
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                            .blendMode(.screen)
                                                            .opacity(0.22)
                                                            .blur(radius: 6)
                                                            .rotationEffect(.degrees(16))
                                                        )

                                                    // Bottom caption overlay
                                                    VStack {
                                                        Spacer()
                                                        Text(item.name)
                                                            .font(.caption2.weight(.semibold))
                                                            .foregroundColor(.white)
                                                            .lineLimit(2)
                                                            .multilineTextAlignment(.center)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 4)
                                                            .background(Color.black.opacity(0.25))
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                            .padding(6)
                                                    }
                                                    .frame(width: 100, height: 100)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding()
                            }
                            .padding(.horizontal, 16)

                            Spacer(minLength: 40)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showCommunityInbox) {
                CommunityInboxView(viewModel: communityInboxVM)
                    .preferredColorScheme(.dark)
            }
            .onAppear {
                reloadFeaturedUserCarPhoto()
                refreshGarageSnapshot()
                loadFeaturedMerch()
                refreshFeaturedCardsIfNeeded()
                Task { await communityInboxVM.refresh() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    reloadFeaturedUserCarPhoto()
                    refreshGarageSnapshot()
                    loadFeaturedMerch()
                    refreshFeaturedCardsIfNeeded()
                    Task { await communityInboxVM.refresh() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .empireCarsDidSync)) { _ in
                reloadFeaturedUserCarPhoto()
                refreshGarageSnapshot()
            }
            .onReceive(NotificationCenter.default.publisher(for: .empireCommunityDidPost)) { _ in
                refreshFeaturedCardsIfNeeded(force: true)
                Task { await communityInboxVM.refresh() }
            }
        }
    }

    private func refreshGarageSnapshot() {
        garageSnapshot = LocalStore.shared.fetchCars(context: modelContext, userKey: currentUserId)
    }

    private func reloadFeaturedUserCarPhoto() {
        let currentUserId = UserDefaults.standard.string(forKey: "currentUserId") ?? "default"
        let cars = LocalStore.shared.fetchCars(context: modelContext, userKey: currentUserId)

        for car in cars {
            guard let fileName = car.photoFileName,
                  let data = loadCarPhotoFromDocuments(fileName: fileName),
                  UIImage(data: data) != nil else {
                continue
            }
            featuredUserCarPhotoData = data
            return
        }

        featuredUserCarPhotoData = nil
    }

    private func loadCarPhotoFromDocuments(fileName: String) -> Data? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsURL.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }

    private func loadHomeMeets() {
        if isLoadingMeets { return }
        if let lastMeetsRefreshAt,
           Date().timeIntervalSince(lastMeetsRefreshAt) < 120,
           !meets.isEmpty {
            return
        }
        isLoadingMeets = true
        meetsError = nil

        Task {
            let service = SupabaseMeetsService()
            do {
                let items = try await service.fetchUpcomingMeets()
                await MainActor.run {
                    self.meets = items
                    self.isLoadingMeets = false
                    self.meetsError = nil
                    self.lastMeetsRefreshAt = Date()
                }
            } catch {
                await MainActor.run {
                    self.meets = []
                    self.isLoadingMeets = false
                    let msg = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.meetsError = msg.isEmpty ? "Failed to load meets" : msg
                }
            }
        }
    }

    private func refreshFeaturedCardsIfNeeded(force: Bool = false) {
        if !force,
           let lastFeaturedCardsRefreshAt,
           Date().timeIntervalSince(lastFeaturedCardsRefreshAt) < 90,
           !communityVM.posts.isEmpty {
            return
        }

        lastFeaturedCardsRefreshAt = Date()
        Task {
            await socialStore.refreshFromBackend()
            await communityVM.refresh()
        }
    }

    private func fallbackAssetName(for post: CommunityPost) -> String {
        if let make = post.make?.lowercased(), make.contains("mustang") {
            return "68_blaze"
        }
        if let make = post.make?.lowercased(), make.contains("honda") {
            return "civic_si_fg2"
        }
        return "prelude_bb2"
    }

    private func relatedMerch(for item: MerchItem) -> [MerchItem] {
        let all = Array((featuredMerch + MerchCatalog.featured + MerchCatalog.bestSellers + MerchCatalog.newArrivals).uniqued(on: \.id))
        return Array(all.filter { $0.id != item.id }.prefix(4))
    }

    private func loadFeaturedMerch() {
        let cached = LocalStore.shared.fetchMerch(context: modelContext)
        if !cached.isEmpty {
            featuredMerch = Array(cached.prefix(3))
        } else {
            featuredMerch = Array(MerchCatalog.featured.prefix(3))
        }

        if isRefreshingFeaturedMerch {
            return
        }

        if let lastFeaturedMerchRefreshAt,
           Date().timeIntervalSince(lastFeaturedMerchRefreshAt) < 30 {
            return
        }

        isRefreshingFeaturedMerch = true
        lastFeaturedMerchRefreshAt = Date()

        Task {
            defer {
                Task { @MainActor in
                    isRefreshingFeaturedMerch = false
                }
            }
            do {
                let fresh = try await SupabaseMerchService().fetchMerch()
                guard !fresh.isEmpty else { return }
                await MainActor.run {
                    LocalStore.shared.cacheMerch(fresh, context: modelContext)
                    featuredMerch = Array(fresh.prefix(3))
                }
            } catch {
                AppTelemetry.shared.record(error: error, context: "home.featured_merch")
            }
        }
    }

}

@MainActor
final class CommunityInboxViewModel: ObservableObject {
    @Published var items: [CommunityInboxItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let service = SupabaseCommunityService()
    private var currentUserId: String { UserDefaults.standard.string(forKey: "currentUserId") ?? "" }
    private var lastSeenKey: String {
        "community_inbox_last_seen_\(currentUserId.lowercased())"
    }

    var unreadCount: Int {
        guard let lastSeenAt else { return items.count }
        return items.filter { $0.createdAt > lastSeenAt }.count
    }

    var lastSeenAt: Date? {
        UserDefaults.standard.object(forKey: lastSeenKey) as? Date
    }

    func refresh() async {
        guard !isLoading else { return }
        let userId = currentUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else {
            items = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            items = try await service.fetchInboxItems(currentUserId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllSeen() {
        UserDefaults.standard.set(Date(), forKey: lastSeenKey)
        UNUserNotificationCenter.current().setBadgeCount(0)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        objectWillChange.send()
    }

    func postPhotoURL(for item: CommunityInboxItem) -> URL? {
        guard let path = item.postPhotoPath else { return nil }
        return service.publicURL(for: path, variant: .thumbnail)
    }

    func avatarURL(for item: CommunityInboxItem) -> URL? {
        guard let path = item.actorAvatarPath else { return nil }
        return service.avatarPublicURL(for: path, variant: .avatar)
    }
}

private struct CommunityInboxView: View {
    @ObservedObject var viewModel: CommunityInboxViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: CommunityInboxItemKind? = nil

    private var filteredItems: [CommunityInboxItem] {
        guard let selectedFilter else { return viewModel.items }
        return viewModel.items.filter { $0.kind == selectedFilter }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color("EmpireMint").opacity(0.14), .clear], center: .top, startRadius: 20, endRadius: 300)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    filterBar
                        .padding(.top, 6)

                    if viewModel.isLoading && viewModel.items.isEmpty {
                        Spacer()
                        ProgressView().tint(Color("EmpireMint"))
                        Spacer()
                    } else if filteredItems.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredItems) { item in
                                    CommunityInboxCard(
                                        item: item,
                                        avatarURL: viewModel.avatarURL(for: item),
                                        postPhotoURL: viewModel.postPhotoURL(for: item)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.refresh()
            viewModel.markAllSeen()
        }
        .onDisappear {
            viewModel.markAllSeen()
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                inboxFilterPill(title: "All", count: viewModel.items.count, isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                ForEach(CommunityInboxItemKind.allCases, id: \.rawValue) { kind in
                    inboxFilterPill(
                        title: kind.title,
                        count: viewModel.items.filter { $0.kind == kind }.count,
                        isSelected: selectedFilter == kind
                    ) {
                        selectedFilter = kind
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func inboxFilterPill(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(isSelected ? Color.black.opacity(0.18) : Color.white.opacity(0.06)))
            }
            .foregroundStyle(isSelected ? Color("EmpireMint") : .white.opacity(0.74))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? Color("EmpireMint").opacity(0.16) : Color.white.opacity(0.05)))
            .overlay(Capsule().stroke(isSelected ? Color("EmpireMint").opacity(0.65) : Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bell.badge")
                .font(.system(size: 34))
                .foregroundStyle(Color("EmpireMint").opacity(0.5))
            Text("No community activity yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Likes, comments, follows, and thread replies will show up here.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

private struct CommunityInboxCard: View {
    let item: CommunityInboxItem
    let avatarURL: URL?
    let postPhotoURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(titleLine)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(item.createdAt.relativeFormatted)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer(minLength: 8)
                    kindBadge
                }

                if let preview = item.previewText?.trimmingCharacters(in: .whitespacesAndNewlines), !preview.isEmpty {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }
            }

            thumbnail
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color("EmpireMint").opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var titleLine: String {
        let actor = item.actorUsername?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? item.actorUsername!
            : "A driver"
        switch item.kind {
        case .like:
            return "\(actor) liked your \(item.postCarName) post"
        case .comment:
            return "\(actor) commented on your \(item.postCarName) post"
        case .reply:
            return "\(actor) replied in a thread you joined"
        case .follow:
            return "\(actor) started following you"
        }
    }

    private var kindBadge: some View {
        Text(item.kind.title.uppercased())
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(item.kind.tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Capsule().fill(item.kind.tint.opacity(0.16)))
            .overlay(Capsule().stroke(item.kind.tint.opacity(0.5), lineWidth: 1))
    }

    private var avatar: some View {
        Group {
            if let avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarFallback
                    }
                }
            } else {
                avatarFallback
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var avatarFallback: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .overlay(
                Image(systemName: item.kind.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.kind.tint)
            )
    }

    private var thumbnail: some View {
        Group {
            if let postPhotoURL {
                AsyncImage(url: postPhotoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        thumbnailFallback
                    }
                }
            } else {
                thumbnailFallback
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var thumbnailFallback: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                Image(systemName: item.kind == .follow ? "person.crop.circle.badge.plus" : "car.fill")
                    .foregroundStyle(item.kind == .follow ? item.kind.tint.opacity(0.75) : Color("EmpireMint").opacity(0.5))
            )
    }
}

private extension CommunityInboxItemKind {
    var title: String {
        switch self {
        case .like: return "Likes"
        case .comment: return "Comments"
        case .reply: return "Replies"
        case .follow: return "Follows"
        }
    }

    var tint: Color {
        switch self {
        case .like: return Color("EmpireMint")
        case .comment: return .cyan
        case .reply: return Color(red: 0.72, green: 0.48, blue: 0.95)
        case .follow: return Color(red: 0.98, green: 0.78, blue: 0.18)
        }
    }

    var symbol: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "bubble.left.fill"
        case .reply: return "arrowshape.turn.up.left.fill"
        case .follow: return "person.badge.plus.fill"
        }
    }
}

private struct HomeFeaturedCardItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String
    let localImageData: Data?
    let remoteImageURL: URL?
    let fallbackImageName: String?
    let score: Int
    let authorKey: String?

    init(
        id: String,
        title: String,
        subtitle: String,
        badge: String,
        localImageData: Data? = nil,
        remoteImageURL: URL? = nil,
        fallbackImageName: String? = nil,
        score: Int = 0,
        authorKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.localImageData = localImageData
        self.remoteImageURL = remoteImageURL
        self.fallbackImageName = fallbackImageName
        self.score = score
        self.authorKey = authorKey
    }
}

private final class HomeFeaturedImageCache {
    static let shared = HomeFeaturedImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 64
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

private actor HomeFeaturedImagePipeline {
    static let shared = HomeFeaturedImagePipeline()

    private var inFlightTasks: [URL: Task<UIImage?, Never>] = [:]

    func loadImage(from url: URL) async -> UIImage? {
        if let cachedImage = await MainActor.run(body: {
            HomeFeaturedImageCache.shared.image(for: url)
        }) {
            return cachedImage
        }

        if let existingTask = inFlightTasks[url] {
            return await existingTask.value
        }

        let task = Task<UIImage?, Never> {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      let image = UIImage(data: data) else {
                    return nil
                }

                await MainActor.run {
                    HomeFeaturedImageCache.shared.insert(image, for: url)
                }
                return image
            } catch {
                return nil
            }
        }

        inFlightTasks[url] = task
        let image = await task.value
        inFlightTasks[url] = nil
        return image
    }
}

private final class HomeFeaturedImageLoader: ObservableObject {
    @Published private(set) var image: UIImage? = nil
    @Published private(set) var didFail = false

    private let url: URL
    private var hasAttemptedLoad = false

    init(url: URL) {
        self.url = url
    }

    func loadIfNeeded() async {
        guard !hasAttemptedLoad else { return }
        hasAttemptedLoad = true

        if let cachedImage = HomeFeaturedImageCache.shared.image(for: url) {
            await MainActor.run {
                image = cachedImage
            }
            return
        }

        await MainActor.run {
            didFail = false
        }

        let loadedImage = await HomeFeaturedImagePipeline.shared.loadImage(from: url)
        await MainActor.run {
            image = loadedImage
            didFail = loadedImage == nil
        }
    }
}

private struct HomeFeaturedRemoteImage<Success: View, Placeholder: View, Failure: View>: View {
    let success: (Image) -> Success
    let placeholder: () -> Placeholder
    let failure: () -> Failure

    @StateObject private var loader: HomeFeaturedImageLoader

    init(
        url: URL,
        @ViewBuilder success: @escaping (Image) -> Success,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.success = success
        self.placeholder = placeholder
        self.failure = failure
        _loader = StateObject(wrappedValue: HomeFeaturedImageLoader(url: url))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                success(Image(uiImage: image))
            } else if loader.didFail {
                failure()
            } else {
                placeholder()
            }
        }
        .task {
            await loader.loadIfNeeded()
        }
    }
}

private struct HomeFeaturedCard: View {
    let card: HomeFeaturedCardItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .frame(width: 150, height: 180)
                .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear, Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                )

            imageContent
                .scaledToFill()
                .frame(width: 150, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.16), Color.black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white.opacity(0.18), location: 0.5),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .opacity(0.22)
            .blur(radius: 8)
            .rotationEffect(.degrees(16))

            VStack(alignment: .leading, spacing: 6) {
                Text(card.badge.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("EmpireMint"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.28)))
                    .overlay(Capsule().stroke(Color("EmpireMint").opacity(0.26), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(card.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(width: 150, height: 180, alignment: .bottomLeading)
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let data = card.localImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
        } else if let remoteImageURL = card.remoteImageURL {
            HomeFeaturedRemoteImage(url: remoteImageURL) { image in
                image
                    .resizable()
            } placeholder: {
                fallbackImage
            } failure: {
                fallbackImage
            }
        } else {
            fallbackImage
        }
    }

    @ViewBuilder
    private var fallbackImage: some View {
        if let fallbackImageName = card.fallbackImageName {
            Image(fallbackImageName)
                .resizable()
        } else {
            ZStack {
                Color.white.opacity(0.05)
                Image(systemName: "car.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color("EmpireMint").opacity(0.34))
            }
        }
    }
}

private extension Array {
    func uniqued<Key: Hashable>(on keyPath: KeyPath<Element, Key>) -> [Element] {
        var seen: Set<Key> = []
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}

// MARK: — Glass Card Component
struct GlassCard<Content: View>: View {
    let height: CGFloat?
    let content: Content

    init(height: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.height = height
        self.content = content()
    }

    var body: some View {
        VStack {
            content
        }
        .frame(maxWidth: .infinity, minHeight: height ?? 0)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.screen)
            }
        )
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.5), radius: 18, y: 6)
    }
}

// MARK: - Home Header
private struct HomeHeader: View {
    @Binding var showSettings: Bool
    @Binding var showCommunityInbox: Bool
    let communityUnreadCount: Int
    @State private var query: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Welcome back")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        showCommunityInbox = true
                    } label: {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 32, height: 32)
                            .overlay(Image(systemName: "bell").foregroundStyle(.white))
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .overlay(alignment: .topTrailing) {
                                if communityUnreadCount > 0 {
                                    Text("\(min(communityUnreadCount, 9))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color("EmpireMint")))
                                        .offset(x: 4, y: -4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        showSettings = true
                    } label: {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 32, height: 32)
                            .overlay(Image(systemName: "gearshape").foregroundStyle(.white))
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
