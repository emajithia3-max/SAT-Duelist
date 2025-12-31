import SwiftUI

// MARK: - Stack Builder Game
// Stack blocks as high as you can! Periodic questions pause the game.

struct StackBuilderGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var stackedBlocks: [StackBlock] = []
    @State private var movingBlock: StackBlock?
    @State private var blockDirection: CGFloat = 1
    @State private var score: Int = 0
    @State private var blocksStacked: Int = 0
    @State private var gameEnded = false
    @State private var perfectStreak: Int = 0
    @State private var lastBlockWidth: CGFloat = 120

    // Question state
    @State private var showQuestion = false
    @State private var currentQuestion: LoadedQuestion?
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var questionsAnswered: Int = 0
    @State private var questionsCorrect: Int = 0

    let questionInterval: Int = 5 // Question every 5 blocks stacked
    let blockHeight: CGFloat = 30
    let baseWidth: CGFloat = 120
    let blockSpeed: CGFloat = 4

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Background
                    SkyBackgroundView()

                    // Stacked blocks
                    ForEach(stackedBlocks) { block in
                        StackBlockView(block: block)
                    }

                    // Moving block
                    if let block = movingBlock, !showQuestion {
                        StackBlockView(block: block)
                    }

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            heightDisplay
                            Spacer()
                            streakDisplay
                            Spacer()
                            scoreDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)

                        Spacer()

                        if !showQuestion && !gameEnded && movingBlock != nil {
                            Text("TAP TO DROP!")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.cyan.opacity(0.8))
                                .padding(.bottom, 40)
                        }
                    }

                    // Tap area
                    if !showQuestion && !gameEnded {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dropBlock()
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
            guard !gameEnded && !showQuestion else { return }
            updateGame()
        }
    }

    // MARK: - Height Display

    private var heightDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.cyan)
            Text("\(blocksStacked)")
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

    // MARK: - Streak Display

    private var streakDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundColor(perfectStreak > 0 ? DesignSystem.Colors.orange : DesignSystem.Colors.textMuted)
            Text("\(perfectStreak)")
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

    // MARK: - Question Overlay

    private func questionOverlay(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 20) {
            Text("BONUS FLOOR!")
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
            Text("TOWER COMPLETE!")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.cyan)

            VStack(spacing: 16) {
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "arrow.up", label: "Height", value: "\(blocksStacked) blocks", color: DesignSystem.Colors.cyan)
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

        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        // Create base block
        let baseBlock = StackBlock(
            id: UUID(),
            x: screenWidth / 2,
            y: screenHeight - 100,
            width: baseWidth,
            height: blockHeight,
            color: blockColor(for: 0)
        )
        stackedBlocks.append(baseBlock)

        // Create first moving block
        spawnNewBlock()
    }

    private func blockColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "#FF6B6B"),
            Color(hex: "#4ECDC4"),
            Color(hex: "#FFE66D"),
            Color(hex: "#A855F7"),
            Color(hex: "#51CF66"),
            Color(hex: "#FF9F43")
        ]
        return colors[index % colors.count]
    }

    private func spawnNewBlock() {
        let screenWidth = UIScreen.main.bounds.width
        let topBlock = stackedBlocks.last!

        let newBlock = StackBlock(
            id: UUID(),
            x: 0,
            y: topBlock.y - blockHeight - 5,
            width: lastBlockWidth,
            height: blockHeight,
            color: blockColor(for: blocksStacked + 1)
        )
        movingBlock = newBlock
        blockDirection = 1
    }

    private func updateGame() {
        guard var block = movingBlock else { return }

        let screenWidth = UIScreen.main.bounds.width

        // Move block
        block.x += blockSpeed * blockDirection

        // Bounce off edges
        if block.x + block.width / 2 >= screenWidth {
            blockDirection = -1
        } else if block.x - block.width / 2 <= 0 {
            blockDirection = 1
        }

        movingBlock = block
    }

    private func dropBlock() {
        guard var block = movingBlock else { return }
        guard let topBlock = stackedBlocks.last else { return }

        HapticsManager.shared.buttonPress()

        // Calculate overlap
        let leftEdge = max(block.x - block.width / 2, topBlock.x - topBlock.width / 2)
        let rightEdge = min(block.x + block.width / 2, topBlock.x + topBlock.width / 2)
        let overlap = rightEdge - leftEdge

        if overlap <= 0 {
            // Complete miss - game over
            endGame()
            return
        }

        // Check if perfect placement
        let isPerfect = abs(block.x - topBlock.x) < 5

        if isPerfect {
            // Perfect placement!
            perfectStreak += 1
            score += 100 + (perfectStreak * 10)
            HapticsManager.shared.correctAnswer()

            // Keep block same width
            block.x = topBlock.x
        } else {
            // Trim the block
            perfectStreak = 0
            let newWidth = overlap
            let newX = (leftEdge + rightEdge) / 2

            block.width = newWidth
            block.x = newX
            lastBlockWidth = newWidth

            score += 50

            // Too small - game over
            if newWidth < 20 {
                endGame()
                return
            }
        }

        block.y = topBlock.y - blockHeight - 5
        stackedBlocks.append(block)
        movingBlock = nil
        blocksStacked += 1

        // Trigger question periodically
        if blocksStacked % questionInterval == 0 {
            triggerQuestion()
        } else {
            // Spawn next block
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                spawnNewBlock()
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
            // Bonus: restore block width a bit
            lastBlockWidth = min(baseWidth, lastBlockWidth + 20)
        } else {
            HapticsManager.shared.incorrectAnswer()
            // Shrink block as penalty
            lastBlockWidth = max(30, lastBlockWidth - 20)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showQuestion = false

            if engine.hasMoreQuestions {
                currentQuestion = engine.nextQuestion()
            }

            spawnNewBlock()
        }
    }

    private func endGame() {
        gameEnded = true
        movingBlock = nil
        HapticsManager.shared.gameTransition()
    }

    private func resetGame() {
        gameEnded = false
        showQuestion = false
        score = 0
        blocksStacked = 0
        perfectStreak = 0
        questionsAnswered = 0
        questionsCorrect = 0
        lastBlockWidth = baseWidth
        stackedBlocks.removeAll()
        movingBlock = nil
        Task {
            await startGame()
        }
    }
}

// MARK: - Models

struct StackBlock: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var color: Color
}

// MARK: - Views

struct StackBlockView: View {
    let block: StackBlock

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [block.color, block.color.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: block.width, height: block.height)
            .shadow(color: block.color.opacity(0.5), radius: 5)
            .position(x: block.x, y: block.y)
    }
}

struct SkyBackgroundView: View {
    var body: some View {
        ZStack {
            // Sky gradient
            LinearGradient(
                colors: [
                    Color(hex: "#1a1a2e"),
                    Color(hex: "#16213e"),
                    Color(hex: "#0f3460")
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Clouds/atmosphere
            GeometryReader { geometry in
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(0.05))
                        .frame(width: CGFloat.random(in: 100...200))
                        .position(
                            x: CGFloat(i) * geometry.size.width / 4,
                            y: CGFloat.random(in: 100...300)
                        )
                        .blur(radius: 30)
                }
            }
        }
    }
}
