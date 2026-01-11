import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSettings = false
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header with profile info
                    VStack(spacing: 16) {
                        // Profile Image
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color("EmpireMint"), Color.cyan],
                                        startPoint:  .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: Color("EmpireMint").opacity(0.5), radius: 20, x: 0, y:  10)

                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        . padding(.top, 20)

                        // User Info
                        VStack(spacing: 8) {
                            Text(authViewModel.currentUser?.username ?? "User")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text(authViewModel.currentUser?.email ??  "email@example.com")
                                . font(.subheadline)
                                . foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal)

                    // Stats Cards
                    HStack(spacing: 12) {
                        ProfileStatCard(title: "Cars", value: "0")
                        ProfileStatCard(title: "Meets", value: "0")
                        ProfileStatCard(title: "Posts", value: "0")
                    }
                    .padding(.horizontal)

                    // Options
                    VStack(spacing:  12) {
                        Button {
                            print("Navigate to garage")
                        } label: {
                            GlassOptionRow(icon: "car.fill", title: "My Garage")
                        }
                        .buttonStyle(. plain)

                        Button {
                            print("Navigate to meets")
                        } label: {
                            GlassOptionRow(icon: "calendar", title: "My Meets")
                        }
                        .buttonStyle(.plain)

                        Button {
                            print("Navigate to saved")
                        } label: {
                            GlassOptionRow(icon: "bookmark.fill", title: "Saved")
                        }
                        .buttonStyle(.plain)

                        Button {
                            showSettings = true
                        } label: {
                            GlassOptionRow(icon: "gearshape.fill", title: "Settings")
                        }
                        .buttonStyle(.plain)

                        // Logout Button
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            authViewModel.logout()
                        } label:  {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow. right")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    . frame(width: 40)

                                Text("Logout")
                                    .font(.body)
                                    .fontWeight(. semibold)
                                    .foregroundColor(. red)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red.opacity(0.5))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16, style:  .continuous)
                                    . fill(. ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: Color.red.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(. plain)
                    }
                    .padding(.horizontal)

                    Spacer(minLength:  100)
                }
                .padding(.vertical)
            }
        }
        .sheet(isPresented: $showSettings) {
            Text("Settings (Coming Soon)")
                .font(.title)
                .foregroundColor(. white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
