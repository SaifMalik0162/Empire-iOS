import SwiftUI

struct VIPDashboardView: View {
    @StateObject private var store = StoreKitManager.shared

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    perksGrid
                    quickActions
                    memberCard
                }
                .padding(20)
            }
        }
        .navigationTitle("VIP Dashboard")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("Empire VIP")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(store.isVIP ? "Active Member" : "Not Active")
                    .font(.subheadline)
                    .foregroundStyle(store.isVIP ? .green : .red)
            }
            Spacer()
        }
    }

    private var perksGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Perks")
                .foregroundStyle(.white)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                perkCard(title: "Meet Access", subtitle: "Early RSVPs & entry", icon: "calendar.badge.plus")
                perkCard(title: "VIP Threads", subtitle: "Member-only posts", icon: "text.bubble.fill")
                perkCard(title: "Crew Finder", subtitle: "Join local groups", icon: "person.3.fill")
                perkCard(title: "Spotlight", subtitle: "Get featured", icon: "camera.fill")
            }
        }
    }

    private func perkCard(title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.yellow)
                Spacer()
            }
            Text(title)
                .foregroundStyle(.white)
                .font(.headline)
            Text(subtitle)
                .foregroundStyle(.white.opacity(0.7))
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.04), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.12))
        )
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .foregroundStyle(.white)
                .font(.headline)
            HStack(spacing: 12) {
                actionButton(title: "RSVP Meet", icon: "calendar.badge.plus")
                actionButton(title: "Post to VIP", icon: "square.and.pencil")
                actionButton(title: "Find Crews", icon: "person.3.fill")
            }
        }
    }

    private func actionButton(title: String, icon: String) -> some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.footnote)
            }
            .foregroundStyle(.black)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.yellow)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .yellow.opacity(0.35), radius: 8, x: 0, y: 6)
        }
    }

    private var memberCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Member Card")
                .foregroundStyle(.white)
                .font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Empire VIP")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Status: \(store.isVIP ? "Active" : "Inactive")")
                        .foregroundStyle(store.isVIP ? .green : .red)
                }
                Spacer()
                Image(systemName: "qrcode")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Color.yellow.opacity(0.25), .yellow.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
        }
    }
}

#Preview {
    NavigationStack { VIPDashboardView() }
}
