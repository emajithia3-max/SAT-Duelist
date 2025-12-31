import SwiftUI

// MARK: - Color Match Game
// Match the target color by tapping the correct tile! Periodic questions pause the game.

struct ColorMatchGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var targetColor: GameColor = .red
    @State private var tiles: [ColorTile] = []
    @State private var score: Int = 0
    @State private var matchCount: Int = 0
    @State private var lives: Int = 3
    @State private var gameEnded = false
    @State private var streak: Int = 0
    @State private var maxStreak: Int = 0
    @State private var timeRemaining: Double = 60
    @State private var showFeedback = false
    @State private var feedbackCorrect = false

    // Question state
    @State private var showQuestion = false
    @State private var currentQuestion: LoadedQuestion?
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var questionsAnswered: Int = 0
    @State private var questionsCorrect: Int = 0

    let questionInterval: Int = 8 // Question every 8 matches
    let gridSize: Int = 4
    let gameTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Background
                    colorMatchBackground

                    VStack(spacing: 20) {
                        // Top bar
                        HStack {
                            livesDisplay
                            Spacer()
                            timerDisplay
                            Spacer()
                            scoreDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)

                        Spacer()

                        if !gameEnded && !showQuestion {
                            // Target color indicator
                            targetColorView

                            // Color grid
                            colorGrid(geometry: geometry)

                            // Streak indicator
                            if streak > 1 {
                                Text("🔥 \(streak) STREAK!")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(DesignSystem.Colors.orange)
                            }
                        }

                        Spacer()
                    }

                    // Feedback overlay
                    if showFeedback {
                        feedbackOverlay
                    }

                    // Question overlay
                    if showQuestion, let question = currentQuestion {
                        questionOverlay(question)
                    }

                    // Game over
                    if gameEnded {
                        gameOverOverlay
                    }
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await startGame()
        }
        .onReceive(gameTimer) { _ in
            guard !gameEnded && !showQuestion else { return }
            updateTimer()
        }
    }

    // MARK: - Background

    private var colorMatchBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#1a1a2e"),
                    Color(hex: "#16213e"),
                    Color(hex: "#0f3460")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated color circles in background
            GeometryReader { geometry in
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(GameColor.allCases[i % GameColor.allCases.count].color.opacity(0.1))
                        .frame(width: CGFloat.random(in: 80...150))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 30)
                }
            }
        }
    }

    // MARK: - Lives Display

    private var livesDisplay: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < lives ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundColor(i < lives ? DesignSystem.Colors.red : DesignSystem.Colors.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 12))
                .foregroundColor(timeRemaining < 10 ? DesignSystem.Colors.red : DesignSystem.Colors.cyan)
            Text(String(format: "%.0f", timeRemaining))
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Score Display

    private var scoreDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.orange)
            Text("\(score)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            HapticsManager.shared.buttonPress()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.elevated.opacity(0.9))
                )
        }
    }

    // MARK: - Target Color View

    private var targetColorView: some View {
        VStack(spacing: 12) {
            Text("MATCH THIS COLOR")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            RoundedRectangle(cornerRadius: 16)
                .fill(targetColor.color)
                .frame(width: 100, height: 100)
                .shadow(color: targetColor.color.opacity(0.5), radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.3), lineWidth: 3)
                )

            Text(targetColor.name.uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(targetColor.color)
        }
        .padding(.top, 20)
    }

    // MARK: - Color Grid

    private func colorGrid(geometry: GeometryProxy) -> some View {
        let tileSize = (geometry.size.width - 80) / CGFloat(gridSize)

        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 10), count: gridSize),
            spacing: 10
        ) {
            ForEach(tiles) { tile in
                Button {
                    tapTile(tile)
                } label: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tile.color.color)
                        .frame(width: tileSize, height: tileSize)
                        .shadow(color: tile.color.color.opacity(0.4), radius: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.2), lineWidth: 2)
                        )
                }
                .buttonStyle(TileButtonStyle())
            }
        }
        .padding(.horizontal, 30)
    }

    // MARK: - Feedback Overlay

    private var feedbackOverlay: some View {
        VStack {
            Image(systemName: feedbackCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(feedbackCorrect ? DesignSystem.Colors.cyan : DesignSystem.Colors.red)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Question Overlay

    private func questionOverlay(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 20) {
            Text("BONUS ROUND!")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DesignSystem.Colors.orange)

            Text(question.question.question)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, 16)

            VStack(spacing: 12) {
                ForEach(question.question.allAnswers, id: \.self) { answer in
                    Button {
                        selectAnswer(answer)
                    } label: {
                        Text(answer)
                            .font(DesignSystem.Typography.body())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(buttonColor(for: answer, question: question))
                            )
                    }
                    .disabled(showResult)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignSystem.Colors.primaryBackground.opacity(0.98))
        )
        .padding(.horizontal, 20)
    }

    private func buttonColor(for answer: String, question: LoadedQuestion) -> Color {
        if showResult {
            if answer == question.question.correctAnswer {
                return DesignSystem.Colors.cyan
            } else if answer == selectedAnswer {
                return DesignSystem.Colors.red
            }
        }
        return DesignSystem.Colors.primary
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 24) {
            Text("GAME OVER!")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.cyan)

            VStack(spacing: 16) {
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "paintpalette.fill", label: "Matches", value: "\(matchCount)", color: DesignSystem.Colors.primary)
                StatRow(icon: "flame.fill", label: "Best Streak", value: "\(maxStreak)", color: DesignSystem.Colors.orange)
                StatRow(icon: "checkmark.circle.fill", label: "Questions", value: "\(questionsCorrect)/\(questionsAnswered)", color: DesignSystem.Colors.cyan)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            PrimaryButton(title: "Play Again") {
                resetGame()
            }

            Button { dismiss() } label: {
                Text("Exit")
                    .font(DesignSystem.Typography.button())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignSystem.Colors.primaryBackground.opacity(0.95))
        )
        .padding(20)
    }

    // MARK: - Game Logic

    private func startGame() async {
        await engine.loadQuestions()
        engine.configureSession(scope: scope, config: config)
        currentQuestion = engine.startSession()

        generateNewRound()
    }

    private func generateNewRound() {
        // Pick new target color
        targetColor = GameColor.allCases.randomElement()!

        // Generate tiles - ensure at least one matches target
        var newTiles: [ColorTile] = []

        // Add 1-3 matching tiles
        let matchingCount = Int.random(in: 1...3)
        for _ in 0..<matchingCount {
            newTiles.append(ColorTile(id: UUID(), color: targetColor))
        }

        // Fill rest with random non-matching colors
        let remainingCount = (gridSize * gridSize) - matchingCount
        let otherColors = GameColor.allCases.filter { $0 != targetColor }
        for _ in 0..<remainingCount {
            newTiles.append(ColorTile(id: UUID(), color: otherColors.randomElement()!))
        }

        // Shuffle tiles
        tiles = newTiles.shuffled()
    }

    private func updateTimer() {
        timeRemaining -= 0.1

        if timeRemaining <= 0 {
            endGame()
        }

        // Warning haptic when low on time
        if timeRemaining == 10 {
            HapticsManager.shared.gameTransition()
        }
    }

    private func tapTile(_ tile: ColorTile) {
        if tile.color == targetColor {
            // Correct match!
            HapticsManager.shared.correctAnswer()
            streak += 1
            maxStreak = max(maxStreak, streak)
            matchCount += 1

            // Score with streak bonus
            let baseScore = 100
            let streakBonus = min(streak - 1, 5) * 20
            score += baseScore + streakBonus

            // Add time bonus
            timeRemaining = min(60, timeRemaining + 2)

            showFeedbackAnimation(correct: true)

            // Check for question trigger
            if matchCount % questionInterval == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    triggerQuestion()
                }
            } else {
                // Generate new round
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    generateNewRound()
                }
            }
        } else {
            // Wrong match
            HapticsManager.shared.incorrectAnswer()
            streak = 0
            lives -= 1

            showFeedbackAnimation(correct: false)

            if lives <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    endGame()
                }
            }
        }
    }

    private func showFeedbackAnimation(correct: Bool) {
        feedbackCorrect = correct
        withAnimation(.easeOut(duration: 0.2)) {
            showFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.2)) {
                showFeedback = false
            }
        }
    }

    private func triggerQuestion() {
        showQuestion = true
        showResult = false
        selectedAnswer = nil
    }

    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer
        showResult = true
        questionsAnswered += 1

        let isCorrect = answer == currentQuestion?.question.correctAnswer

        if isCorrect {
            HapticsManager.shared.correctAnswer()
            questionsCorrect += 1
            score += 200
            // Bonus time for correct answer
            timeRemaining = min(60, timeRemaining + 5)
        } else {
            HapticsManager.shared.incorrectAnswer()
            lives -= 1
            if lives <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    endGame()
                }
                return
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showQuestion = false

            if engine.hasMoreQuestions {
                currentQuestion = engine.nextQuestion()
            }

            generateNewRound()
        }
    }

    private func endGame() {
        gameEnded = true
        HapticsManager.shared.gameTransition()
    }

    private func resetGame() {
        gameEnded = false
        showQuestion = false
        score = 0
        matchCount = 0
        lives = 3
        streak = 0
        maxStreak = 0
        timeRemaining = 60
        questionsAnswered = 0
        questionsCorrect = 0
        Task {
            await startGame()
        }
    }
}

// MARK: - Models

enum GameColor: CaseIterable {
    case red, blue, green, yellow, purple, orange

    var color: Color {
        switch self {
        case .red: return Color(hex: "#FF5252")
        case .blue: return Color(hex: "#448AFF")
        case .green: return Color(hex: "#69F0AE")
        case .yellow: return Color(hex: "#FFD740")
        case .purple: return Color(hex: "#B388FF")
        case .orange: return Color(hex: "#FF9100")
        }
    }

    var name: String {
        switch self {
        case .red: return "Red"
        case .blue: return "Blue"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .purple: return "Purple"
        case .orange: return "Orange"
        }
    }
}

struct ColorTile: Identifiable {
    let id: UUID
    let color: GameColor
}

// MARK: - Button Style

struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
