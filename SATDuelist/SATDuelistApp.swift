import SwiftUI

// MARK: - SAT Duelist App
// Main entry point

@main
struct SATDuelistApp: App {
    init() {
        // Prepare haptic generators
        HapticsManager.shared.prepareAll()

        // Configure appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }

    private func configureAppearance() {
        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color(hex: "#0F1117"))
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // Tab bar appearance (if used)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color(hex: "#0F1117"))

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}

// MARK: - Content View (Root)

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Play tab
            GameSelectionView()
                .tabItem {
                    Label("Play", systemImage: "gamecontroller.fill")
                }
                .tag(0)

            // Leaderboard tab
            LeaderboardView()
                .tabItem {
                    Label("Ranks", systemImage: "trophy.fill")
                }
                .tag(1)

            // Profile tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(2)
        }
        .tint(Color(hex: "#7C6CFF"))
    }
}

#Preview {
    ContentView()
}
