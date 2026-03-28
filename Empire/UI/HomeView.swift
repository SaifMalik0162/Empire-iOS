import SwiftUI
import UIKit
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Meets Data
    @State private var meets: [Meet] = []
    @State private var showSettings: Bool = false
    @State private var isLoadingMeets = false
    @State private var meetsError: String? = nil
    @State private var featuredUserCarPhotoData: Data? = nil
    @State private var featuredMerch: [MerchItem] = []
    @State private var isRefreshingFeaturedMerch = false
    @State private var lastFeaturedMerchRefreshAt: Date? = nil
    @State private var lastMeetsRefreshAt: Date? = nil

    // MARK: - Data Sources
    private let communityCars: [Car] = [
        Car(name: "Honda Prelude BB2", description: "@officialtobysemple — Clean BB2 build", imageName: "prelude_bb2", horsepower: 450, stage: 3),
        Car(name: "Civic Si Coupe", description: "@fg2_corey — FG2 Si coupe", imageName: "civic_si_fg2", horsepower: 220, stage: 2),
        Car(name: "1968 Mustang", description: "347 Stroker V8", imageName: "68_blaze", horsepower: 350, stage: 2)
    ]

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
                            HomeHeader(showSettings: $showSettings)
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
                                        // Prepend static first image card: car0
                                        ZStack {
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

                                            Group {
                                                if let data = featuredUserCarPhotoData, let uiImage = UIImage(data: data) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                } else {
                                                    Image("car0")
                                                        .resizable()
                                                }
                                            }
                                            .scaledToFill()
                                            .frame(width: 150, height: 180)
                                            .cornerRadius(20)
                                            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

                                            LinearGradient(
                                                colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                            .cornerRadius(20)

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
                                        }

                                        ForEach(communityCars.indices, id: \.self) { idx in
                                            ZStack {
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

                                                Image(communityCars[idx].imageName)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 150, height: 180)
                                                    .cornerRadius(20)
                                                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)

                                                LinearGradient(
                                                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                                .cornerRadius(20)

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
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.leading, 16)
                                    .padding(.trailing, 60)
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
            .onAppear {
                reloadFeaturedUserCarPhoto()
                loadFeaturedMerch()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    reloadFeaturedUserCarPhoto()
                    loadFeaturedMerch()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .empireCarsDidSync)) { _ in
                reloadFeaturedUserCarPhoto()
            }
        }
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
    @State private var query: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Welcome back")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 10) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "bell").foregroundStyle(.white))
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
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
