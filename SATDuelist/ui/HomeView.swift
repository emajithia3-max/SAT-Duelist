import SwiftUI

// MARK: - Game Settings Manager
// Manages hidden games list and user preferences

class GameSettingsManager: ObservableObject {
    static let shared = GameSettingsManager()

    @Published var hiddenGames: Set<String> {
        didSet {
            saveHiddenGames()
        }
    }

    @Published var recentlyPlayedGames: [String] = []
    @Published var gamesPlayed: Int = 0
    @Published var totalScore: Int = 0
    @Published var questionsAnswered: Int = 0
    @Published var correctAnswers: Int = 0

    private let hiddenGamesKey = "hiddenGames"
    private let recentGamesKey = "recentlyPlayedGames"
    private let gamesPlayedKey = "gamesPlayed"
    private let totalScoreKey = "totalScore"
    private let questionsAnsweredKey = "questionsAnswered"
    private let correctAnswersKey = "correctAnswers"

    private init() {
        // Load hidden games
        if let saved = UserDefaults.standard.stringArray(forKey: hiddenGamesKey) {
            hiddenGames = Set(saved)
        } else {
            hiddenGames = []
        }

        // Load recent games
        recentlyPlayedGames = UserDefaults.standard.stringArray(forKey: recentGamesKey) ?? []

        // Load stats
        gamesPlayed = UserDefaults.standard.integer(forKey: gamesPlayedKey)
        totalScore = UserDefaults.standard.integer(forKey: totalScoreKey)
        questionsAnswered = UserDefaults.standard.integer(forKey: questionsAnsweredKey)
        correctAnswers = UserDefaults.standard.integer(forKey: correctAnswersKey)
    }

    private func saveHiddenGames() {
        UserDefaults.standard.set(Array(hiddenGames), forKey: hiddenGamesKey)
    }

    func hideGame(_ gameId: String) {
        hiddenGames.insert(gameId)
    }

    func unhideGame(_ gameId: String) {
        hiddenGames.remove(gameId)
    }

    func isGameHidden(_ gameId: String) -> Bool {
        hiddenGames.contains(gameId)
    }

    func recordGamePlayed(_ gameId: String) {
        gamesPlayed += 1
        UserDefaults.standard.set(gamesPlayed, forKey: gamesPlayedKey)

        // Update recent games (keep last 5)
        recentlyPlayedGames.removeAll { $0 == gameId }
        recentlyPlayedGames.insert(gameId, at: 0)
        if recentlyPlayedGames.count > 5 {
            recentlyPlayedGames = Array(recentlyPlayedGames.prefix(5))
        }
        UserDefaults.standard.set(recentlyPlayedGames, forKey: recentGamesKey)
    }

    func recordScore(_ score: Int) {
        totalScore += score
        UserDefaults.standard.set(totalScore, forKey: totalScoreKey)
    }

    func recordQuestion(correct: Bool) {
        questionsAnswered += 1
        if correct {
            correctAnswers += 1
        }
        UserDefaults.standard.set(questionsAnswered, forKey: questionsAnsweredKey)
        UserDefaults.standard.set(correctAnswers, forKey: correctAnswersKey)
    }

    var accuracy: Double {
        guard questionsAnswered > 0 else { return 0 }
        return Double(correctAnswers) / Double(questionsAnswered) * 100
    }

    func getAvailableArcadeGames() -> [GameMode] {
        GameMode.allCases
            .filter { $0.isArcadeGame && !isGameHidden($0.id) }
    }

    func getRandomGame() -> GameMode? {
        let available = getAvailableArcadeGames()
        return available.randomElement()
    }
}

// MARK: - Home View
// Main home screen with START button and dashboard

struct HomeView: View {
    @ObservedObject private var settings = GameSettingsManager.shared
    @State private var selectedGame: GameMode?
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Background
            DesignSystem.Colors.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Dashboard section
                dashboardSection
                    .padding(.top, 60)

                Spacer()

                // Play button section
                playButtonSection

                Spacer()

                // Recent games section
                if !settings.recentlyPlayedGames.isEmpty {
                    recentGamesSection
                        .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 20)
        }
        .fullScreenCover(item: $selectedGame) { game in
            ScopeSelectionView(gameMode: game)
        }
    }

    // MARK: - Dashboard Section

    private var dashboardSection: some View {
        VStack(spacing: 20) {
            // Title
            VStack(spacing: 4) {
                Text("SAT Duelist")
                    .font(DesignSystem.Typography.screenTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Master the SAT through games")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }

            // Stats cards
            HStack(spacing: 12) {
                DashboardStatCard(
                    icon: "gamecontroller.fill",
                    value: "\(settings.gamesPlayed)",
                    label: "Games",
                    color: DesignSystem.Colors.primary
                )

                DashboardStatCard(
                    icon: "checkmark.circle.fill",
                    value: "\(settings.questionsAnswered)",
                    label: "Questions",
                    color: DesignSystem.Colors.cyan
                )

                DashboardStatCard(
                    icon: "percent",
                    value: String(format: "%.0f%%", settings.accuracy),
                    label: "Accuracy",
                    color: DesignSystem.Colors.orange
                )
            }

            // Most recent topic studied
            if let recentGame = settings.recentlyPlayedGames.first,
               let game = GameMode.allCases.first(where: { $0.id == recentGame }) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textMuted)

                    Text("Last played: \(game.rawValue)")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textMuted)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
    }

    // MARK: - Play Button Section

    private var playButtonSection: some View {
        VStack(spacing: 24) {
            // Available games count
            let availableCount = settings.getAvailableArcadeGames().count
            Text("\(availableCount) games available")
                .font(DesignSystem.Typography.caption())
                .foregroundColor(DesignSystem.Colors.textMuted)

            // Big play button
            Button {
                startRandomGame()
            } label: {
                ZStack {
                    // Outer glow pulse
                    Circle()
                        .fill(DesignSystem.Colors.primary.opacity(0.2))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)

                    // Button background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.gradientTop,
                                    DesignSystem.Colors.gradientBottom
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.5), radius: 20, x: 0, y: 10)

                    // Play icon
                    Image(systemName: "play.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 4) // Optical centering
                }
            }
            .buttonStyle(PlayButtonStyle())
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulseAnimation = true
                }
            }

            Text("START")
                .font(DesignSystem.Typography.cardTitle())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    // MARK: - Recent Games Section

    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Played")
                .font(DesignSystem.Typography.caption())
                .foregroundColor(DesignSystem.Colors.textMuted)

            HStack(spacing: 12) {
                ForEach(settings.recentlyPlayedGames.prefix(4), id: \.self) { gameId in
                    if let game = GameMode.allCases.first(where: { $0.id == gameId }) {
                        RecentGameBadge(game: game) {
                            selectedGame = game
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func startRandomGame() {
        HapticsManager.shared.gameTransition()
        selectedGame = settings.getRandomGame()
    }
}

// MARK: - Play Button Style

struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Dashboard Stat Card

struct DashboardStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Recent Game Badge

struct RecentGameBadge: View {
    let game: GameMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(game.color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: game.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(game.color)
            }
        }
        .buttonStyle(CardButtonStyle())
    }
}

#Preview {
    HomeView()
}
