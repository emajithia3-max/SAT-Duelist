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

    init() {
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
    @StateObject private var settings = GameSettingsManager.shared
    @State private var showGameplay = false
    @State private var currentGame: GameMode?
    @State private var pulseAnimation = false

    var body: some View {
        CinematicContainer(vignette: true, bloom: true) {
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
        .fullScreenCover(isPresented: $showGameplay) {
            if let game = currentGame {
                GameplayFlowView(initialGame: game)
            }
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
                            currentGame = game
                            showGameplay = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func startRandomGame() {
        HapticsManager.shared.gameTransition()
        if let game = settings.getRandomGame() {
            currentGame = game
            showGameplay = true
        }
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

// MARK: - Gameplay Flow View
// Manages the random game selection and game-over flow

struct GameplayFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = GameSettingsManager.shared

    let initialGame: GameMode

    @State private var currentGame: GameMode
    @State private var showGame = true
    @State private var showGameOver = false
    @State private var gameResult: GameResult?
    @State private var showHidePopup = false

    init(initialGame: GameMode) {
        self.initialGame = initialGame
        _currentGame = State(initialValue: initialGame)
    }

    var body: some View {
        ZStack {
            if showGame {
                // Current game with scope selection
                GameWithScopeView(
                    gameMode: currentGame,
                    onGameEnd: { result in
                        handleGameEnd(result: result)
                    },
                    onDismiss: {
                        dismiss()
                    },
                    onHideRequest: {
                        showHidePopup = true
                    }
                )
            }

            if showGameOver, let result = gameResult {
                GameOverFlowView(
                    result: result,
                    currentGame: currentGame,
                    onPlayNext: {
                        playNextGame()
                    },
                    onGoHome: {
                        dismiss()
                    }
                )
            }

            // Hide game popup
            if showHidePopup {
                hideGamePopup
            }
        }
    }

    private var hideGamePopup: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    showHidePopup = false
                }

            VStack(spacing: 20) {
                Text("Hide \(currentGame.rawValue)?")
                    .font(DesignSystem.Typography.cardTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("This game won't appear in random selection. You can unhide it in Settings.")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Button {
                        showHidePopup = false
                    } label: {
                        Text("Cancel")
                            .font(DesignSystem.Typography.button())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.elevated)
                            )
                    }

                    Button {
                        settings.hideGame(currentGame.id)
                        showHidePopup = false
                        // Start next game after hiding
                        playNextGame()
                    } label: {
                        Text("Hide Game")
                            .font(DesignSystem.Typography.button())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.red)
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .padding(.horizontal, 32)
        }
    }

    private func handleGameEnd(result: GameResult) {
        gameResult = result
        settings.recordGamePlayed(currentGame.id)
        settings.recordScore(result.score)
        showGame = false
        showGameOver = true
    }

    private func playNextGame() {
        showGameOver = false
        gameResult = nil

        if let nextGame = settings.getRandomGame() {
            currentGame = nextGame
            showGame = true
        } else {
            // No games available (all hidden)
            dismiss()
        }
    }
}

// MARK: - Game Result

struct GameResult {
    let won: Bool
    let score: Int
    let questionsCorrect: Int
    let questionsTotal: Int
}

// MARK: - Game Over Flow View

struct GameOverFlowView: View {
    let result: GameResult
    let currentGame: GameMode
    let onPlayNext: () -> Void
    let onGoHome: () -> Void

    var body: some View {
        CinematicContainer(vignette: true, bloom: true) {
            VStack(spacing: 32) {
                Spacer()

                // Result title
                VStack(spacing: 12) {
                    Text(result.won ? "VICTORY!" : "GAME OVER")
                        .font(DesignSystem.Typography.screenTitle())
                        .foregroundColor(result.won ? DesignSystem.Colors.cyan : DesignSystem.Colors.red)

                    Text(currentGame.rawValue)
                        .font(DesignSystem.Typography.cardTitle())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Stats
                VStack(spacing: 16) {
                    GameOverStatRow(icon: "star.fill", label: "Score", value: "\(result.score)", color: DesignSystem.Colors.orange)

                    if result.questionsTotal > 0 {
                        GameOverStatRow(
                            icon: "checkmark.circle.fill",
                            label: "Questions",
                            value: "\(result.questionsCorrect)/\(result.questionsTotal)",
                            color: DesignSystem.Colors.cyan
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(DesignSystem.Colors.cardBackground)
                )

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    Button {
                        HapticsManager.shared.buttonPress()
                        onPlayNext()
                    } label: {
                        Text("Next Game")
                            .font(DesignSystem.Typography.button())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                Capsule()
                                    .fill(LinearGradient.primaryButton)
                            )
                    }

                    Button {
                        HapticsManager.shared.buttonPress()
                        onGoHome()
                    } label: {
                        Text("Home")
                            .font(DesignSystem.Typography.button())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Game Over Stat Row

struct GameOverStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

// MARK: - Game With Scope View
// Wraps game selection with scope and adds hide button

struct GameWithScopeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = QuestionEngine()

    let gameMode: GameMode
    let onGameEnd: (GameResult) -> Void
    let onDismiss: () -> Void
    let onHideRequest: () -> Void

    @State private var selectedScope: ScopeOption = .anythingGoes
    @State private var showGame = false
    @State private var selectedTopic: String?
    @State private var scopeCounts: ScopeCounts?

    var body: some View {
        NavigationStack {
            CinematicContainer {
                VStack(spacing: 0) {
                    // Header
                    headerSection

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Game info
                            gameInfoSection

                            // Quick scope options
                            VStack(spacing: 12) {
                                QuickScopeButton(
                                    option: .anythingGoes,
                                    isSelected: selectedScope == .anythingGoes,
                                    count: scopeCounts?.total ?? 0
                                ) {
                                    selectedScope = .anythingGoes
                                }

                                QuickScopeButton(
                                    option: .english,
                                    isSelected: selectedScope == .english,
                                    count: scopeCounts?.readingAndWriting ?? 0
                                ) {
                                    selectedScope = .english
                                }

                                QuickScopeButton(
                                    option: .math,
                                    isSelected: selectedScope == .math,
                                    count: scopeCounts?.math ?? 0
                                ) {
                                    selectedScope = .math
                                }
                            }
                            .padding(.horizontal, 20)

                            Spacer(minLength: 100)
                        }
                        .padding(.top, 20)
                    }

                    // Bottom buttons
                    bottomButtonsSection
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadQuestions()
            }
            .fullScreenCover(isPresented: $showGame) {
                GameWrapperView(
                    gameMode: gameMode,
                    scope: buildScope(),
                    config: buildConfig(),
                    onGameEnd: onGameEnd
                )
            }
        }
    }

    private var headerSection: some View {
        HStack {
            Button {
                HapticsManager.shared.buttonPress()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.elevated)
                    )
            }

            Spacer()

            Text("Select Scope")
                .font(DesignSystem.Typography.cardTitle())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var gameInfoSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(gameMode.color.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: gameMode.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(gameMode.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(gameMode.rawValue)
                    .font(DesignSystem.Typography.cardTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(gameMode.description)
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .padding(.horizontal, 20)
    }

    private var bottomButtonsSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(DesignSystem.Colors.cardBorder)

            // Start button
            Button {
                HapticsManager.shared.gameTransition()
                showGame = true
            } label: {
                Text("Play \(gameMode.rawValue)")
                    .font(DesignSystem.Typography.button())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule()
                            .fill(LinearGradient.primaryButton)
                    )
            }

            // Hide game button
            Button {
                HapticsManager.shared.buttonPress()
                onHideRequest()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 14))
                    Text("I don't like this game")
                        .font(DesignSystem.Typography.caption())
                }
                .foregroundColor(DesignSystem.Colors.textMuted)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .background(DesignSystem.Colors.primaryBackground)
    }

    private func loadQuestions() async {
        await engine.loadQuestions()
        scopeCounts = engine.getScopeCounts()
    }

    private func buildScope() -> ScopeSelection {
        switch selectedScope {
        case .anythingGoes:
            return .all
        case .english:
            if let topic = selectedTopic {
                return .topicSpecific(section: .readingAndWriting, topic: topic)
            }
            return .sectionOnly(.readingAndWriting)
        case .math:
            if let topic = selectedTopic {
                return .topicSpecific(section: .math, topic: topic)
            }
            return .sectionOnly(.math)
        }
    }

    private func buildConfig() -> SessionConfig {
        switch gameMode {
        case .speedRush:
            return .timed(60)
        case .bubblePop:
            return .timed(60)
        case .colorMatch:
            return .timed(45)
        default:
            return .default
        }
    }
}

// MARK: - Quick Scope Button

struct QuickScopeButton: View {
    let option: ScopeOption
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticsManager.shared.selectionChanged()
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(option.color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.rawValue)
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(count) questions")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textMuted)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? option.color : DesignSystem.Colors.cardBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(option.color)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? option.color : DesignSystem.Colors.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(CardButtonStyle())
    }
}

// MARK: - Game Wrapper View
// Wrapper that handles game completion reporting

struct GameWrapperView: View {
    @Environment(\.dismiss) private var dismiss

    let gameMode: GameMode
    let scope: ScopeSelection
    let config: SessionConfig
    let onGameEnd: (GameResult) -> Void

    var body: some View {
        ZStack {
            gameContent
        }
    }

    @ViewBuilder
    private var gameContent: some View {
        switch gameMode {
        case .duelClassic:
            DuelClassicGame(scope: scope, config: config)
        case .speedRush:
            SpeedRushGame(scope: scope, config: config)
        case .survival:
            SurvivalModeGame(scope: scope, config: config)
        case .meteorDefense:
            MeteorDefenseGame(scope: scope, config: config)
        case .towerClimb:
            TowerClimbGame(scope: scope, config: config)
        case .snakeFeast:
            SnakeFeastGame(scope: scope, config: config)
        case .breakoutBlitz:
            BreakoutBlitzGame(scope: scope, config: config)
        case .flappyScholar:
            FlappyScholarGame(scope: scope, config: config)
        case .asteroidDodge:
            AsteroidDodgeGame(scope: scope, config: config)
        case .fruitSlice:
            FruitSliceGame(scope: scope, config: config)
        case .gravityRunner:
            GravityRunnerGame(scope: scope, config: config)
        case .bubblePop:
            BubblePopGame(scope: scope, config: config)
        case .pinballWizard:
            PinballWizardGame(scope: scope, config: config)
        case .laserMaze:
            LaserMazeGame(scope: scope, config: config)
        case .rhythmBlaster:
            RhythmBlasterGame(scope: scope, config: config)
        case .spaceShooter:
            SpaceShooterGame(scope: scope, config: config)
        case .stackBuilder:
            StackBuilderGame(scope: scope, config: config)
        case .colorMatch:
            ColorMatchGame(scope: scope, config: config)
        }
    }
}

#Preview {
    HomeView()
}
