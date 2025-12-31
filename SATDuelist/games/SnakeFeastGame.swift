import SwiftUI

// MARK: - Snake Feast Game
// Classic snake game - eat correct answers to grow, wrong answers shrink you!

struct SnakeFeastGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var snake: [CGPoint] = [CGPoint(x: 5, y: 10)]
    @State private var direction: Direction = .right
    @State private var nextDirection: Direction = .right
    @State private var foodItems: [FoodItem] = []
    @State private var currentQuestion: LoadedQuestion?
    @State private var score: Int = 0
    @State private var gameEnded = false
    @State private var isPaused = false
    @State private var gridSize: CGSize = .zero
    @State private var lastMoveTime: Date = Date()

    let cellSize: CGFloat = 20
    let gridWidth: Int = 17
    let gridHeight: Int = 25
    let moveInterval: TimeInterval = 0.15

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Game grid background
                    gameBackground

                    // Snake
                    ForEach(Array(snake.enumerated()), id: \.offset) { index, segment in
                        SnakeSegmentView(
                            position: segment,
                            cellSize: cellSize,
                            isHead: index == 0,
                            color: DesignSystem.Colors.cyan
                        )
                    }

                    // Food items (answers)
                    ForEach(foodItems) { food in
                        FoodItemView(food: food, cellSize: cellSize)
                    }

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            scoreDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)

                        Spacer()

                        // Question display at bottom
                        if let question = currentQuestion {
                            questionDisplay(question)
                        }

                        // Control buttons
                        controlPad
                            .padding(.bottom, 30)
                    }

                    // Game over
                    if gameEnded {
                        gameOverOverlay
                    }
                }
            }
            .onAppear {
                gridSize = CGSize(width: CGFloat(gridWidth) * cellSize, height: CGFloat(gridHeight) * cellSize)
            }
        }
        .ignoresSafeArea()
        .task {
            await startGame()
        }
        .onReceive(gameLoop) { _ in
            guard !gameEnded && !isPaused else { return }
            updateGame()
        }
    }

    // MARK: - Game Background

    private var gameBackground: some View {
        VStack(spacing: 0) {
            ForEach(0..<gridHeight, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<gridWidth, id: \.self) { col in
                        Rectangle()
                            .fill((row + col) % 2 == 0 ?
                                  DesignSystem.Colors.elevated.opacity(0.3) :
                                  DesignSystem.Colors.cardBackground.opacity(0.3))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 2)
        )
        .position(x: UIScreen.main.bounds.width / 2, y: 280)
    }

    // MARK: - Score Display

    private var scoreDisplay: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundColor(DesignSystem.Colors.orange)
            Text("\(score)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Divider()
                .frame(height: 20)

            Text("Length: \(snake.count)")
                .font(DesignSystem.Typography.caption())
                .foregroundColor(DesignSystem.Colors.textSecondary)
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

    // MARK: - Question Display

    private func questionDisplay(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 8) {
            Text(question.question.question)
                .font(DesignSystem.Typography.caption())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)

            Text("Eat the correct answer!")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.cyan)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground.opacity(0.95))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Control Pad

    private var controlPad: some View {
        VStack(spacing: 8) {
            // Up button
            Button { changeDirection(.up) } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 60, height: 50)
                    .background(DesignSystem.Colors.elevated)
                    .cornerRadius(12)
            }

            HStack(spacing: 60) {
                // Left button
                Button { changeDirection(.left) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .bold))
                        .frame(width: 60, height: 50)
                        .background(DesignSystem.Colors.elevated)
                        .cornerRadius(12)
                }

                // Right button
                Button { changeDirection(.right) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .bold))
                        .frame(width: 60, height: 50)
                        .background(DesignSystem.Colors.elevated)
                        .cornerRadius(12)
                }
            }

            // Down button
            Button { changeDirection(.down) } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 60, height: 50)
                    .background(DesignSystem.Colors.elevated)
                    .cornerRadius(12)
            }
        }
        .foregroundColor(DesignSystem.Colors.textPrimary)
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
                StatRow(icon: "checkmark.circle.fill", label: "Correct", value: "\(engine.correctAnswers)", color: DesignSystem.Colors.green)
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
            spawnFood(for: question)
        }

        // Initialize snake in center
        snake = [
            CGPoint(x: 8, y: 12),
            CGPoint(x: 7, y: 12),
            CGPoint(x: 6, y: 12)
        ]
        direction = .right
        nextDirection = .right
    }

    private func spawnFood(for question: LoadedQuestion) {
        foodItems.removeAll()

        let answers = question.question.allAnswers
        var usedPositions: Set<String> = Set(snake.map { "\(Int($0.x)),\(Int($0.y))" })

        for answer in answers {
            var position: CGPoint
            repeat {
                position = CGPoint(
                    x: CGFloat(Int.random(in: 1..<gridWidth-1)),
                    y: CGFloat(Int.random(in: 1..<gridHeight-1))
                )
            } while usedPositions.contains("\(Int(position.x)),\(Int(position.y))")

            usedPositions.insert("\(Int(position.x)),\(Int(position.y))")

            let isCorrect = answer == question.question.correctAnswer
            foodItems.append(FoodItem(
                id: UUID(),
                position: position,
                answer: answer,
                isCorrect: isCorrect
            ))
        }
    }

    private func updateGame() {
        let now = Date()
        guard now.timeIntervalSince(lastMoveTime) >= moveInterval else { return }
        lastMoveTime = now

        direction = nextDirection
        moveSnake()
    }

    private func moveSnake() {
        guard let head = snake.first else { return }

        var newHead = head
        switch direction {
        case .up: newHead.y -= 1
        case .down: newHead.y += 1
        case .left: newHead.x -= 1
        case .right: newHead.x += 1
        }

        // Check wall collision
        if newHead.x < 0 || newHead.x >= CGFloat(gridWidth) ||
           newHead.y < 0 || newHead.y >= CGFloat(gridHeight) {
            endGame()
            return
        }

        // Check self collision
        if snake.dropFirst().contains(where: { $0.x == newHead.x && $0.y == newHead.y }) {
            endGame()
            return
        }

        // Check food collision
        if let foodIndex = foodItems.firstIndex(where: {
            Int($0.position.x) == Int(newHead.x) && Int($0.position.y) == Int(newHead.y)
        }) {
            let food = foodItems[foodIndex]
            eatFood(food)
            foodItems.remove(at: foodIndex)

            // Add new head (snake grows)
            snake.insert(newHead, at: 0)
        } else {
            // Move snake (remove tail)
            snake.insert(newHead, at: 0)
            snake.removeLast()
        }
    }

    private func eatFood(_ food: FoodItem) {
        if food.isCorrect {
            HapticsManager.shared.correctAnswer()
            score += 100 * snake.count
            // Snake grows automatically by not removing tail
            advanceQuestion()
        } else {
            HapticsManager.shared.incorrectAnswer()
            // Shrink snake
            if snake.count > 2 {
                snake.removeLast()
                snake.removeLast()
            } else {
                endGame()
            }
            // Respawn food for same question
            if let question = currentQuestion {
                spawnFood(for: question)
            }
        }
    }

    private func advanceQuestion() {
        if engine.hasMoreQuestions {
            if let question = engine.nextQuestion() {
                currentQuestion = question
                spawnFood(for: question)
            }
        } else {
            endGame()
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

    private func endGame() {
        gameEnded = true
        HapticsManager.shared.gameTransition()
    }

    private func resetGame() {
        gameEnded = false
        score = 0
        foodItems.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Direction Enum

enum Direction {
    case up, down, left, right
}

// MARK: - Food Item

struct FoodItem: Identifiable {
    let id: UUID
    let position: CGPoint
    let answer: String
    let isCorrect: Bool
}

// MARK: - Snake Segment View

struct SnakeSegmentView: View {
    let position: CGPoint
    let cellSize: CGFloat
    let isHead: Bool
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: isHead ? 6 : 4)
            .fill(isHead ? color : color.opacity(0.7))
            .frame(width: cellSize - 2, height: cellSize - 2)
            .overlay(
                isHead ?
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                : nil
            )
            .position(
                x: (UIScreen.main.bounds.width - CGFloat(17) * cellSize) / 2 + position.x * cellSize + cellSize / 2,
                y: 280 - CGFloat(25) * cellSize / 2 + position.y * cellSize + cellSize / 2
            )
    }
}

// MARK: - Food Item View

struct FoodItemView: View {
    let food: FoodItem
    let cellSize: CGFloat

    @State private var pulse = false

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(DesignSystem.Colors.orange.opacity(0.3))
                .frame(width: cellSize + 8, height: cellSize + 8)
                .scaleEffect(pulse ? 1.2 : 1.0)

            // Food circle
            Circle()
                .fill(DesignSystem.Colors.orange)
                .frame(width: cellSize - 4, height: cellSize - 4)

            // Answer text
            Text(String(food.answer.prefix(2)))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
        }
        .position(
            x: (UIScreen.main.bounds.width - CGFloat(17) * cellSize) / 2 + food.position.x * cellSize + cellSize / 2,
            y: 280 - CGFloat(25) * cellSize / 2 + food.position.y * cellSize + cellSize / 2
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
