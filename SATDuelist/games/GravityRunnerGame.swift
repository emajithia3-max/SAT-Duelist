import SwiftUI

// MARK: - Gravity Runner Game
// Endless runner where answering questions flips gravity!

struct GravityRunnerGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var playerY: CGFloat = 400
    @State private var playerVelocity: CGFloat = 0
    @State private var gravityDirection: CGFloat = 1 // 1 = down, -1 = up
    @State private var obstacles: [RunnerObstacle] = []
    @State private var coins: [RunnerCoin] = []
    @State private var currentQuestion: LoadedQuestion?
    @State private var score: Int = 0
    @State private var distance: Int = 0
    @State private var gameEnded = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showQuestion = false
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var canFlip = true

    let gravity: CGFloat = 0.5
    let scrollSpeed: CGFloat = 6
    let groundY: CGFloat = 650
    let ceilingY: CGFloat = 150

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    let obstacleSpawner = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    let questionTimer = Timer.publish(every: 6.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Background layers
                    ParallaxBackgroundView(offset: scrollOffset)

                    // Ground and ceiling
                    VStack {
                        // Ceiling
                        Rectangle()
                            .fill(DesignSystem.Colors.elevated)
                            .frame(height: ceilingY)
                            .overlay(
                                Rectangle()
                                    .fill(DesignSystem.Colors.primary.opacity(0.5))
                                    .frame(height: 4),
                                alignment: .bottom
                            )

                        Spacer()

                        // Ground
                        Rectangle()
                            .fill(DesignSystem.Colors.elevated)
                            .frame(height: geometry.size.height - groundY)
                            .overlay(
                                Rectangle()
                                    .fill(DesignSystem.Colors.cyan.opacity(0.5))
                                    .frame(height: 4),
                                alignment: .top
                            )
                    }

                    // Obstacles
                    ForEach(obstacles) { obstacle in
                        ObstacleView(obstacle: obstacle, scrollOffset: scrollOffset)
                    }

                    // Coins
                    ForEach(coins) { coin in
                        CoinView(coin: coin, scrollOffset: scrollOffset)
                    }

                    // Player
                    PlayerRunnerView(gravityDirection: gravityDirection)
                        .position(x: 100, y: playerY)

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            scoreDisplay
                            Spacer()
                            distanceDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)

                        Spacer()

                        // Flip instruction
                        if !showQuestion {
                            Text("TAP TO FLIP GRAVITY")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(canFlip ? DesignSystem.Colors.cyan : DesignSystem.Colors.textMuted)
                                .padding(.bottom, 20)
                        }
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
                .contentShape(Rectangle())
                .onTapGesture {
                    if !gameEnded && !showQuestion && canFlip {
                        flipGravity()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await startGame()
        }
        .onReceive(gameLoop) { _ in
            guard !gameEnded && !showQuestion else { return }
            updateGame()
        }
        .onReceive(obstacleSpawner) { _ in
            guard !gameEnded && !showQuestion else { return }
            spawnObstacle()
        }
        .onReceive(questionTimer) { _ in
            guard !gameEnded && !showQuestion else { return }
            triggerQuestion()
        }
    }

    // MARK: - Score Display

    private var scoreDisplay: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundColor(DesignSystem.Colors.orange)
            Text("\(score)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Distance Display

    private var distanceDisplay: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.right")
                .foregroundColor(DesignSystem.Colors.cyan)
            Text("\(distance)m")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.elevated.opacity(0.9))
                )
        }
    }

    // MARK: - Question Overlay

    private func questionOverlay(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 16) {
            Text("ANSWER TO UNLOCK FLIP!")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(DesignSystem.Colors.orange)

            Text(question.question.question)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                ForEach(question.question.allAnswers, id: \.self) { answer in
                    Button {
                        selectAnswer(answer)
                    } label: {
                        Text(answer)
                            .font(DesignSystem.Typography.body())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
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
                .fill(DesignSystem.Colors.primaryBackground.opacity(0.95))
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
            Text("GAME OVER")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.red)

            VStack(spacing: 16) {
                StatRow(icon: "arrow.right", label: "Distance", value: "\(distance)m", color: DesignSystem.Colors.cyan)
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "checkmark.circle.fill", label: "Correct", value: "\(engine.correctAnswers)", color: DesignSystem.Colors.cyan)
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

        if let question = engine.startSession() {
            currentQuestion = question
        }

        playerY = groundY - 50
        gravityDirection = 1
    }

    private func flipGravity() {
        HapticsManager.shared.buttonPress()
        gravityDirection *= -1
        canFlip = false

        // Cooldown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            canFlip = true
        }
    }

    private func spawnObstacle() {
        let screenWidth = UIScreen.main.bounds.width
        let isTop = Bool.random()

        let obstacle = RunnerObstacle(
            id: UUID(),
            x: screenWidth + scrollOffset + 100,
            isTop: isTop,
            height: CGFloat.random(in: 80...150)
        )
        obstacles.append(obstacle)

        // Also spawn some coins
        if Bool.random() {
            let coin = RunnerCoin(
                id: UUID(),
                x: screenWidth + scrollOffset + 150,
                y: isTop ? groundY - 100 : ceilingY + 100
            )
            coins.append(coin)
        }
    }

    private func updateGame() {
        // Apply gravity
        playerVelocity += gravity * gravityDirection
        playerY += playerVelocity

        // Clamp to bounds
        if gravityDirection > 0 {
            if playerY >= groundY - 30 {
                playerY = groundY - 30
                playerVelocity = 0
            }
        } else {
            if playerY <= ceilingY + 30 {
                playerY = ceilingY + 30
                playerVelocity = 0
            }
        }

        // Scroll
        scrollOffset += scrollSpeed
        distance = Int(scrollOffset / 10)

        // Check obstacle collisions
        for obstacle in obstacles {
            let obstacleX = obstacle.x - scrollOffset

            if obstacleX > 70 && obstacleX < 130 {
                let playerTop = playerY - 25
                let playerBottom = playerY + 25

                if obstacle.isTop {
                    let obstacleBottom = ceilingY + obstacle.height
                    if playerTop < obstacleBottom {
                        endGame()
                        return
                    }
                } else {
                    let obstacleTop = groundY - obstacle.height
                    if playerBottom > obstacleTop {
                        endGame()
                        return
                    }
                }
            }
        }

        // Collect coins
        for i in coins.indices.reversed() {
            let coinX = coins[i].x - scrollOffset
            let coinY = coins[i].y

            let distance = sqrt(pow(100 - coinX, 2) + pow(playerY - coinY, 2))
            if distance < 40 {
                coins.remove(at: i)
                score += 50
                HapticsManager.shared.selectionChanged()
            }
        }

        // Clean up off-screen objects
        obstacles.removeAll { $0.x - scrollOffset < -100 }
        coins.removeAll { $0.x - scrollOffset < -50 }
    }

    private func triggerQuestion() {
        showQuestion = true
        showResult = false
        selectedAnswer = nil
        canFlip = false
    }

    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer
        showResult = true

        let isCorrect = answer == currentQuestion?.question.correctAnswer

        if isCorrect {
            HapticsManager.shared.correctAnswer()
            score += 100
        } else {
            HapticsManager.shared.incorrectAnswer()
        }

        _ = engine.submitAnswer(answer)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showQuestion = false
            canFlip = isCorrect
            advanceQuestion()
        }
    }

    private func advanceQuestion() {
        if engine.hasMoreQuestions {
            currentQuestion = engine.nextQuestion()
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
        distance = 0
        scrollOffset = 0
        gravityDirection = 1
        canFlip = true
        obstacles.removeAll()
        coins.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Runner Obstacle

struct RunnerObstacle: Identifiable {
    let id: UUID
    let x: CGFloat
    let isTop: Bool
    let height: CGFloat
}

// MARK: - Runner Coin

struct RunnerCoin: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Obstacle View

struct ObstacleView: View {
    let obstacle: RunnerObstacle
    let scrollOffset: CGFloat

    var body: some View {
        let screenX = obstacle.x - scrollOffset

        Rectangle()
            .fill(
                LinearGradient(
                    colors: [DesignSystem.Colors.red, DesignSystem.Colors.red.opacity(0.7)],
                    startPoint: obstacle.isTop ? .top : .bottom,
                    endPoint: obstacle.isTop ? .bottom : .top
                )
            )
            .frame(width: 40, height: obstacle.height)
            .cornerRadius(8)
            .shadow(color: DesignSystem.Colors.red.opacity(0.5), radius: 8)
            .position(
                x: screenX,
                y: obstacle.isTop ? 150 + obstacle.height/2 : 650 - obstacle.height/2
            )
    }
}

// MARK: - Coin View

struct CoinView: View {
    let coin: RunnerCoin
    let scrollOffset: CGFloat

    @State private var rotate = false

    var body: some View {
        let screenX = coin.x - scrollOffset

        Circle()
            .fill(DesignSystem.Colors.orange)
            .frame(width: 25, height: 25)
            .overlay(
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
            )
            .shadow(color: DesignSystem.Colors.orange, radius: 5)
            .scaleEffect(x: rotate ? 0.3 : 1.0)
            .position(x: screenX, y: coin.y)
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: true)) {
                    rotate = true
                }
            }
    }
}

// MARK: - Player Runner View

struct PlayerRunnerView: View {
    let gravityDirection: CGFloat

    @State private var running = false

    var body: some View {
        ZStack {
            // Glow trail
            Ellipse()
                .fill(DesignSystem.Colors.cyan.opacity(0.3))
                .frame(width: 40, height: 20)
                .blur(radius: 8)
                .offset(x: -20)

            // Body
            Capsule()
                .fill(DesignSystem.Colors.cyan)
                .frame(width: 30, height: 50)

            // Head
            Circle()
                .fill(DesignSystem.Colors.cyan)
                .frame(width: 25, height: 25)
                .offset(y: gravityDirection > 0 ? -30 : 30)

            // Eye
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .offset(x: 5, y: gravityDirection > 0 ? -32 : 28)
        }
        .scaleEffect(y: gravityDirection)
        .offset(y: running ? -3 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
                running = true
            }
        }
    }
}

// MARK: - Parallax Background View

struct ParallaxBackgroundView: View {
    let offset: CGFloat

    var body: some View {
        ZStack {
            // Far background
            LinearGradient(
                colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")],
                startPoint: .top,
                endPoint: .bottom
            )

            // Stars (slowest)
            GeometryReader { geometry in
                ForEach(0..<30, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 2)
                        .position(
                            x: (CGFloat(i * 50).truncatingRemainder(dividingBy: geometry.size.width) - offset * 0.1).truncatingRemainder(dividingBy: geometry.size.width),
                            y: CGFloat(i * 30).truncatingRemainder(dividingBy: geometry.size.height * 0.6) + 100
                        )
                }
            }

            // Mid-ground buildings (medium speed)
            GeometryReader { geometry in
                HStack(spacing: 30) {
                    ForEach(0..<10, id: \.self) { i in
                        Rectangle()
                            .fill(Color(hex: "#2a2a4a"))
                            .frame(width: 60, height: CGFloat.random(in: 100...200))
                    }
                }
                .offset(x: -(offset * 0.3).truncatingRemainder(dividingBy: 900))
                .offset(y: 350)
            }
        }
    }
}
