import SwiftUI

// MARK: - Breakout Blitz Game
// Classic brick breaker - destroy bricks, periodic questions for power-ups

struct BreakoutBlitzGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var ballPosition: CGPoint = CGPoint(x: 200, y: 500)
    @State private var ballVelocity: CGPoint = CGPoint(x: 4, y: -4)
    @State private var paddleX: CGFloat = 200
    @State private var bricks: [GameBrick] = []
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var gameEnded = false
    @State private var ballLaunched = false
    @State private var bricksDestroyed: Int = 0

    // Question state
    @State private var showQuestion = false
    @State private var currentQuestion: LoadedQuestion?
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var questionsAnswered: Int = 0
    @State private var questionsCorrect: Int = 0

    let paddleWidth: CGFloat = 100
    let paddleHeight: CGFloat = 16
    let ballRadius: CGFloat = 10
    let questionInterval: Int = 5 // Question every 5 bricks

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
                        BrickGameView(brick: brick)
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
                        HStack {
                            livesDisplay
                            Spacer()
                            scoreDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)

                        Spacer()

                        if !ballLaunched && !gameEnded && !showQuestion {
                            Text("TAP TO LAUNCH")
                                .font(DesignSystem.Typography.button())
                                .foregroundColor(DesignSystem.Colors.cyan)
                                .padding(.bottom, 180)
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
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard !showQuestion else { return }
                            paddleX = min(max(paddleWidth/2, value.location.x), geometry.size.width - paddleWidth/2)
                        }
                )
                .onTapGesture {
                    if !ballLaunched && !gameEnded && !showQuestion {
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
            guard !gameEnded && ballLaunched && !showQuestion else { return }
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
            Text(bricks.isEmpty ? "LEVEL COMPLETE!" : "GAME OVER")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(bricks.isEmpty ? DesignSystem.Colors.cyan : DesignSystem.Colors.red)

            VStack(spacing: 16) {
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "square.fill", label: "Bricks", value: "\(bricksDestroyed)", color: DesignSystem.Colors.cyan)
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

        setupBricks()
        resetBallPosition()
    }

    private func setupBricks() {
        bricks.removeAll()
        let screenWidth = UIScreen.main.bounds.width
        let brickWidth: CGFloat = 50
        let brickHeight: CGFloat = 25
        let cols = Int((screenWidth - 40) / (brickWidth + 5))
        let rows = 5

        let colors: [Color] = [
            DesignSystem.Colors.red,
            DesignSystem.Colors.orange,
            Color(hex: "#FFE66D"),
            Color(hex: "#51CF66"),
            DesignSystem.Colors.cyan
        ]

        for row in 0..<rows {
            for col in 0..<cols {
                let brick = GameBrick(
                    id: UUID(),
                    x: 25 + CGFloat(col) * (brickWidth + 5) + brickWidth/2,
                    y: 150 + CGFloat(row) * (brickHeight + 5),
                    width: brickWidth,
                    height: brickHeight,
                    color: colors[row]
                )
                bricks.append(brick)
            }
        }
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
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        // Move ball
        ballPosition.x += ballVelocity.x
        ballPosition.y += ballVelocity.y

        // Wall collisions
        if ballPosition.x <= ballRadius || ballPosition.x >= screenWidth - ballRadius {
            ballVelocity.x *= -1
            ballPosition.x = max(ballRadius, min(screenWidth - ballRadius, ballPosition.x))
        }

        if ballPosition.y <= ballRadius + 50 {
            ballVelocity.y *= -1
            ballPosition.y = ballRadius + 50
        }

        // Ball fell
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
            let hitPos = (ballPosition.x - paddleX) / (paddleWidth / 2)
            ballVelocity.x = hitPos * 5
            ballVelocity.y = -abs(ballVelocity.y)
        }

        // Brick collisions
        for i in bricks.indices.reversed() {
            let brick = bricks[i]
            if ballPosition.x >= brick.x - brick.width/2 &&
               ballPosition.x <= brick.x + brick.width/2 &&
               ballPosition.y >= brick.y - brick.height/2 &&
               ballPosition.y <= brick.y + brick.height/2 {

                bricks.remove(at: i)
                ballVelocity.y *= -1
                bricksDestroyed += 1
                score += 10
                HapticsManager.shared.selectionChanged()

                // Trigger question periodically
                if bricksDestroyed % questionInterval == 0 {
                    triggerQuestion()
                }

                // Check win
                if bricks.isEmpty {
                    endGame()
                }
                break
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

    private func triggerQuestion() {
        showQuestion = true
        showResult = false
        selectedAnswer = nil
        ballLaunched = false
    }

    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer
        showResult = true
        questionsAnswered += 1

        let isCorrect = answer == currentQuestion?.question.correctAnswer

        if isCorrect {
            HapticsManager.shared.correctAnswer()
            questionsCorrect += 1
            score += 50
        } else {
            HapticsManager.shared.incorrectAnswer()
            lives -= 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showQuestion = false

            if lives <= 0 {
                endGame()
                return
            }

            resetBallPosition()

            if engine.hasMoreQuestions {
                currentQuestion = engine.nextQuestion()
            }
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
        bricksDestroyed = 0
        questionsAnswered = 0
        questionsCorrect = 0
        Task {
            await startGame()
        }
    }
}

// MARK: - Game Brick

struct GameBrick: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let color: Color
}

// MARK: - Brick Game View

struct BrickGameView: View {
    let brick: GameBrick

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [brick.color, brick.color.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: brick.width, height: brick.height)
            .shadow(color: brick.color.opacity(0.5), radius: 3)
            .position(x: brick.x, y: brick.y)
    }
}
