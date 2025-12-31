import SwiftUI

// MARK: - Breakout Blitz Game
// Classic brick breaker - hit the correct answer brick to score!

struct BreakoutBlitzGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var ballPosition: CGPoint = CGPoint(x: 200, y: 500)
    @State private var ballVelocity: CGPoint = CGPoint(x: 4, y: -4)
    @State private var paddleX: CGFloat = 200
    @State private var bricks: [Brick] = []
    @State private var currentQuestion: LoadedQuestion?
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var gameEnded = false
    @State private var ballLaunched = false
    @State private var combo: Int = 0
    @State private var showCombo = false

    let paddleWidth: CGFloat = 100
    let paddleHeight: CGFloat = 16
    let ballRadius: CGFloat = 10
    let brickWidth: CGFloat = 80
    let brickHeight: CGFloat = 40

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Background
                    LinearGradient(
                        colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Bricks
                    ForEach(bricks) { brick in
                        BrickView(brick: brick, width: brickWidth, height: brickHeight)
                    }

                    // Ball
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, DesignSystem.Colors.cyan],
                                center: .center,
                                startRadius: 0,
                                endRadius: ballRadius
                            )
                        )
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .shadow(color: DesignSystem.Colors.cyan, radius: 10)
                        .position(ballPosition)

                    // Paddle
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: paddleWidth, height: paddleHeight)
                        .position(x: paddleX, y: geometry.size.height - 120)
                        .shadow(color: DesignSystem.Colors.primary, radius: 8)

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            livesDisplay
                            Spacer()
                            scoreDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)

                        // Question
                        if let question = currentQuestion {
                            Text(question.question.question)
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                        }

                        Spacer()

                        // Tap to launch
                        if !ballLaunched && !gameEnded {
                            Text("TAP TO LAUNCH")
                                .font(DesignSystem.Typography.button())
                                .foregroundColor(DesignSystem.Colors.cyan)
                                .padding(.bottom, 180)
                        }
                    }

                    // Combo display
                    if showCombo && combo > 1 {
                        Text("\(combo)x COMBO!")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(DesignSystem.Colors.orange)
                            .shadow(color: DesignSystem.Colors.orange, radius: 10)
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Game over
                    if gameEnded {
                        gameOverOverlay
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            paddleX = min(max(paddleWidth/2, value.location.x), geometry.size.width - paddleWidth/2)
                        }
                )
                .onTapGesture {
                    if !ballLaunched && !gameEnded {
                        launchBall()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await startGame()
        }
        .onReceive(gameLoop) { _ in
            guard !gameEnded && ballLaunched else { return }
            updateGame()
        }
    }

    // MARK: - Lives Display

    private var livesDisplay: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < lives ? "heart.fill" : "heart")
                    .foregroundColor(index < lives ? DesignSystem.Colors.red : DesignSystem.Colors.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
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

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 24) {
            Text(lives > 0 ? "LEVEL COMPLETE!" : "GAME OVER")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(lives > 0 ? DesignSystem.Colors.cyan : DesignSystem.Colors.red)

            VStack(spacing: 16) {
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "checkmark.circle.fill", label: "Correct", value: "\(engine.correctAnswers)", color: DesignSystem.Colors.cyan)
                StatRow(icon: "flame.fill", label: "Max Combo", value: "\(combo)x", color: DesignSystem.Colors.orange)
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
            setupBricks(for: question)
        }

        resetBallPosition()
    }

    private func setupBricks(for question: LoadedQuestion) {
        bricks.removeAll()

        let answers = question.question.allAnswers
        let screenWidth = UIScreen.main.bounds.width
        let startY: CGFloat = 180
        let spacing: CGFloat = 10

        let totalWidth = CGFloat(answers.count) * brickWidth + CGFloat(answers.count - 1) * spacing
        let startX = (screenWidth - totalWidth) / 2 + brickWidth / 2

        for (index, answer) in answers.enumerated() {
            let brick = Brick(
                id: UUID(),
                position: CGPoint(x: startX + CGFloat(index) * (brickWidth + spacing), y: startY),
                answer: answer,
                isCorrect: answer == question.question.correctAnswer,
                color: randomBrickColor()
            )
            bricks.append(brick)
        }
    }

    private func randomBrickColor() -> Color {
        let colors: [Color] = [
            DesignSystem.Colors.primary,
            DesignSystem.Colors.cyan,
            DesignSystem.Colors.orange,
            Color(hex: "#E94560"),
            Color(hex: "#3FE0C5")
        ]
        return colors.randomElement() ?? DesignSystem.Colors.primary
    }

    private func resetBallPosition() {
        ballPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 180)
        ballVelocity = CGPoint(x: 0, y: 0)
        ballLaunched = false
    }

    private func launchBall() {
        HapticsManager.shared.buttonPress()
        ballLaunched = true
        let angle = Double.random(in: -0.5...0.5)
        let speed: CGFloat = 7
        ballVelocity = CGPoint(x: sin(angle) * speed, y: -speed)
    }

    private func updateGame() {
        // Move ball
        ballPosition.x += ballVelocity.x
        ballPosition.y += ballVelocity.y

        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        // Wall collisions
        if ballPosition.x <= ballRadius || ballPosition.x >= screenWidth - ballRadius {
            ballVelocity.x *= -1
            ballPosition.x = max(ballRadius, min(screenWidth - ballRadius, ballPosition.x))
        }

        if ballPosition.y <= ballRadius + 50 {
            ballVelocity.y *= -1
            ballPosition.y = ballRadius + 50
        }

        // Ball fell below paddle
        if ballPosition.y >= screenHeight - 80 {
            loseLife()
            return
        }

        // Paddle collision
        let paddleY = screenHeight - 120
        if ballPosition.y + ballRadius >= paddleY - paddleHeight/2 &&
           ballPosition.y - ballRadius <= paddleY + paddleHeight/2 &&
           ballPosition.x >= paddleX - paddleWidth/2 &&
           ballPosition.x <= paddleX + paddleWidth/2 &&
           ballVelocity.y > 0 {

            HapticsManager.shared.selectionChanged()

            // Reflect and add spin based on hit position
            let hitPos = (ballPosition.x - paddleX) / (paddleWidth / 2)
            ballVelocity.x = hitPos * 6
            ballVelocity.y = -abs(ballVelocity.y) * 1.02 // Slight speed increase
            ballVelocity.y = max(ballVelocity.y, -12) // Cap speed
        }

        // Brick collisions
        for (index, brick) in bricks.enumerated().reversed() {
            if ballPosition.x >= brick.position.x - brickWidth/2 &&
               ballPosition.x <= brick.position.x + brickWidth/2 &&
               ballPosition.y >= brick.position.y - brickHeight/2 &&
               ballPosition.y <= brick.position.y + brickHeight/2 {

                hitBrick(at: index)
                ballVelocity.y *= -1
                break
            }
        }
    }

    private func hitBrick(at index: Int) {
        let brick = bricks[index]
        bricks.remove(at: index)

        if brick.isCorrect {
            HapticsManager.shared.correctAnswer()
            combo += 1
            score += 100 * combo
            showComboAnimation()
            advanceQuestion()
        } else {
            HapticsManager.shared.incorrectAnswer()
            combo = 0
            // Respawn bricks for same question
            if let question = currentQuestion {
                setupBricks(for: question)
            }
        }
    }

    private func showComboAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showCombo = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                showCombo = false
            }
        }
    }

    private func loseLife() {
        lives -= 1
        HapticsManager.shared.incorrectAnswer()

        if lives <= 0 {
            endGame()
        } else {
            resetBallPosition()
        }
    }

    private func advanceQuestion() {
        if engine.hasMoreQuestions {
            if let question = engine.nextQuestion() {
                currentQuestion = question
                setupBricks(for: question)
            }
        } else {
            endGame()
        }
    }

    private func endGame() {
        gameEnded = true
        HapticsManager.shared.gameTransition()
    }

    private func resetGame() {
        gameEnded = false
        lives = 3
        score = 0
        combo = 0
        bricks.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Brick Model

struct Brick: Identifiable {
    let id: UUID
    let position: CGPoint
    let answer: String
    let isCorrect: Bool
    let color: Color
}

// MARK: - Brick View

struct BrickView: View {
    let brick: Brick
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [brick.color, brick.color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)
                .shadow(color: brick.color.opacity(0.5), radius: 4)

            Text(brick.answer)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(4)
        }
        .position(brick.position)
    }
}
