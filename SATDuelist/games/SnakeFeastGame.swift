import SwiftUI

// MARK: - Snake Feast Game
// Classic snake game - eat food to grow, periodic questions pause the game

struct SnakeFeastGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var snake: [GridPosition] = []
    @State private var direction: Direction = .right
    @State private var nextDirection: Direction = .right
    @State private var food: GridPosition = GridPosition(x: 10, y: 10)
    @State private var score: Int = 0
    @State private var foodEaten: Int = 0
    @State private var gameEnded = false
    @State private var isPaused = false

    // Question state
    @State private var showQuestion = false
    @State private var currentQuestion: LoadedQuestion?
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var questionsAnswered: Int = 0
    @State private var questionsCorrect: Int = 0

    let gridWidth: Int = 15
    let gridHeight: Int = 20
    let cellSize: CGFloat = 20
    let questionInterval: Int = 3 // Question every 3 food eaten

    let gameLoop = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Background
                    Color(hex: "#0a0a15")

                    // Game grid
                    gameGrid
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 50)

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            scoreDisplay
                            Spacer()
                            lengthDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)

                        Spacer()

                        // Control pad
                        if !showQuestion && !gameEnded {
                            controlPad
                                .padding(.bottom, 30)
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
            }
        }
        .ignoresSafeArea()
        .task {
            await startGame()
        }
        .onReceive(gameLoop) { _ in
            guard !gameEnded && !showQuestion && !isPaused else { return }
            updateGame()
        }
    }

    // MARK: - Game Grid

    private var gameGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<gridHeight, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<gridWidth, id: \.self) { col in
                        cellView(row: row, col: col)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignSystem.Colors.elevated.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 2)
        )
    }

    private func cellView(row: Int, col: Int) -> some View {
        let pos = GridPosition(x: col, y: row)
        let isSnakeHead = snake.first == pos
        let isSnakeBody = snake.dropFirst().contains(pos)
        let isFood = food == pos

        return Rectangle()
            .fill(cellColor(isHead: isSnakeHead, isBody: isSnakeBody, isFood: isFood))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                Group {
                    if isFood {
                        Circle()
                            .fill(DesignSystem.Colors.orange)
                            .padding(3)
                    }
                }
            )
    }

    private func cellColor(isHead: Bool, isBody: Bool, isFood: Bool) -> Color {
        if isHead {
            return DesignSystem.Colors.cyan
        } else if isBody {
            return DesignSystem.Colors.cyan.opacity(0.6)
        } else {
            return Color.clear
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

    // MARK: - Length Display

    private var lengthDisplay: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.right")
                .foregroundColor(DesignSystem.Colors.cyan)
            Text("\(snake.count)")
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

    // MARK: - Control Pad

    private var controlPad: some View {
        VStack(spacing: 8) {
            Button { changeDirection(.up) } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: 70, height: 55)
                    .background(DesignSystem.Colors.elevated)
                    .cornerRadius(12)
            }

            HStack(spacing: 70) {
                Button { changeDirection(.left) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 70, height: 55)
                        .background(DesignSystem.Colors.elevated)
                        .cornerRadius(12)
                }

                Button { changeDirection(.right) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 70, height: 55)
                        .background(DesignSystem.Colors.elevated)
                        .cornerRadius(12)
                }
            }

            Button { changeDirection(.down) } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: 70, height: 55)
                    .background(DesignSystem.Colors.elevated)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Question Overlay

    private func questionOverlay(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 20) {
            Text("QUESTION TIME!")
                .font(.system(size: 14, weight: .bold))
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
            Text("GAME OVER")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.red)

            VStack(spacing: 16) {
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "arrow.up.right", label: "Max Length", value: "\(snake.count)", color: DesignSystem.Colors.cyan)
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

        // Initialize snake in center
        let startX = gridWidth / 2
        let startY = gridHeight / 2
        snake = [
            GridPosition(x: startX, y: startY),
            GridPosition(x: startX - 1, y: startY),
            GridPosition(x: startX - 2, y: startY)
        ]
        direction = .right
        nextDirection = .right
        spawnFood()
    }

    private func spawnFood() {
        var newFood: GridPosition
        repeat {
            newFood = GridPosition(
                x: Int.random(in: 1..<gridWidth-1),
                y: Int.random(in: 1..<gridHeight-1)
            )
        } while snake.contains(newFood)
        food = newFood
    }

    private func updateGame() {
        direction = nextDirection

        guard let head = snake.first else { return }

        var newHead = head
        switch direction {
        case .up: newHead.y -= 1
        case .down: newHead.y += 1
        case .left: newHead.x -= 1
        case .right: newHead.x += 1
        }

        // Wall collision
        if newHead.x < 0 || newHead.x >= gridWidth ||
           newHead.y < 0 || newHead.y >= gridHeight {
            endGame()
            return
        }

        // Self collision
        if snake.contains(newHead) {
            endGame()
            return
        }

        // Move snake
        snake.insert(newHead, at: 0)

        // Check food
        if newHead == food {
            HapticsManager.shared.selectionChanged()
            score += 10
            foodEaten += 1
            spawnFood()

            // Trigger question every few food
            if foodEaten % questionInterval == 0 {
                triggerQuestion()
            }
        } else {
            snake.removeLast()
        }
    }

    private func changeDirection(_ newDirection: Direction) {
        HapticsManager.shared.selectionChanged()
        // Prevent 180-degree turns
        switch (direction, newDirection) {
        case (.up, .down), (.down, .up), (.left, .right), (.right, .left):
            return
        default:
            nextDirection = newDirection
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
            score += 50 // Bonus for correct answer
        } else {
            HapticsManager.shared.incorrectAnswer()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showQuestion = false

            if !isCorrect {
                // Wrong answer ends game
                endGame()
                return
            }

            // Get next question
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
        showQuestion = false
        score = 0
        foodEaten = 0
        questionsAnswered = 0
        questionsCorrect = 0
        Task {
            await startGame()
        }
    }
}

// MARK: - Grid Position

struct GridPosition: Equatable, Hashable {
    var x: Int
    var y: Int
}

// MARK: - Direction

enum Direction {
    case up, down, left, right
}
