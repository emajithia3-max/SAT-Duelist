import SwiftUI

// MARK: - Fruit Slice Game
// Slice all fruit that appears, periodic questions pause the game

struct FruitSliceGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var fruits: [GameFruit] = []
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var gameEnded = false
    @State private var combo: Int = 0
    @State private var fruitsSliced: Int = 0
    @State private var sliceTrail: [CGPoint] = []

    // Question state
    @State private var showQuestion = false
    @State private var currentQuestion: LoadedQuestion?
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var questionsAnswered: Int = 0
    @State private var questionsCorrect: Int = 0

    let questionInterval: Int = 8 // Question every 8 fruits

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    let fruitSpawner = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Dojo background
                    LinearGradient(
                        colors: [Color(hex: "#1a1a2e"), Color(hex: "#2d1b3d")],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Fruits
                    ForEach(fruits) { fruit in
                        FruitGameView(fruit: fruit)
                    }

                    // Slice trail
                    SliceGameTrailView(points: sliceTrail)

                    // UI Overlay
                    VStack {
                        HStack {
                            livesDisplay
                            Spacer()
                            comboDisplay
                            Spacer()
                            scoreDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)

                        Spacer()

                        if !showQuestion && !gameEnded {
                            Text("SLICE ALL THE FRUIT!")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.cyan.opacity(0.8))
                                .padding(.bottom, 40)
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
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            guard !showQuestion && !gameEnded else { return }
                            sliceTrail.append(value.location)
                            if sliceTrail.count > 15 {
                                sliceTrail.removeFirst()
                            }
                            checkSlice(at: value.location)
                        }
                        .onEnded { _ in
                            sliceTrail.removeAll()
                        }
                )
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
        .onReceive(fruitSpawner) { _ in
            guard !gameEnded && !showQuestion else { return }
            spawnFruit()
        }
    }

    // MARK: - Lives Display

    private var livesDisplay: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < lives ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundColor(index < lives ? DesignSystem.Colors.red : DesignSystem.Colors.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Combo Display

    private var comboDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundColor(combo > 0 ? DesignSystem.Colors.orange : DesignSystem.Colors.textMuted)
            Text("\(combo)x")
                .font(DesignSystem.Typography.caption())
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.elevated.opacity(0.9))
                )
        }
    }

    // MARK: - Question Overlay

    private func questionOverlay(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 20) {
            Text("BONUS CHALLENGE!")
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
            Text("GAME OVER")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.red)

            VStack(spacing: 16) {
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "scissors", label: "Sliced", value: "\(fruitsSliced)", color: DesignSystem.Colors.cyan)
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
    }

    private func spawnFruit() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        let colors: [Color] = [
            Color(hex: "#FF6B6B"),
            Color(hex: "#FFA94D"),
            Color(hex: "#51CF66"),
            Color(hex: "#9775FA"),
            DesignSystem.Colors.cyan
        ]

        let fruit = GameFruit(
            id: UUID(),
            x: CGFloat.random(in: 60...(screenWidth - 60)),
            y: screenHeight + 50,
            velocityX: CGFloat.random(in: -2...2),
            velocityY: CGFloat.random(in: -18 ... -14),
            size: CGFloat.random(in: 50...70),
            color: colors.randomElement() ?? .orange,
            rotation: 0
        )
        fruits.append(fruit)
    }

    private func updateGame() {
        let screenHeight = UIScreen.main.bounds.height

        for i in fruits.indices.reversed() {
            // Apply physics
            fruits[i].velocityY += 0.4
            fruits[i].x += fruits[i].velocityX
            fruits[i].y += fruits[i].velocityY
            fruits[i].rotation += 3

            // Remove fruits that fell
            if fruits[i].y > screenHeight + 100 {
                let fruit = fruits[i]
                fruits.remove(at: i)

                if !fruit.sliced {
                    // Missed a fruit
                    lives -= 1
                    combo = 0
                    HapticsManager.shared.incorrectAnswer()

                    if lives <= 0 {
                        endGame()
                    }
                }
            }
        }
    }

    private func checkSlice(at point: CGPoint) {
        for i in fruits.indices.reversed() {
            guard !fruits[i].sliced else { continue }

            let distance = sqrt(pow(point.x - fruits[i].x, 2) + pow(point.y - fruits[i].y, 2))

            if distance < fruits[i].size / 2 + 20 {
                sliceFruit(at: i)
                break
            }
        }
    }

    private func sliceFruit(at index: Int) {
        fruits[index].sliced = true
        HapticsManager.shared.selectionChanged()

        combo += 1
        fruitsSliced += 1
        score += 10 * combo

        // Trigger question periodically
        if fruitsSliced % questionInterval == 0 {
            triggerQuestion()
        }

        // Remove sliced fruit after brief delay
        let fruitId = fruits[index].id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            fruits.removeAll { $0.id == fruitId }
        }
    }

    private func triggerQuestion() {
        showQuestion = true
        showResult = false
        selectedAnswer = nil
        fruits.removeAll() // Clear screen for question
    }

    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer
        showResult = true
        questionsAnswered += 1

        let isCorrect = answer == currentQuestion?.question.correctAnswer

        if isCorrect {
            HapticsManager.shared.correctAnswer()
            questionsCorrect += 1
            score += 100
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
        lives = 3
        score = 0
        combo = 0
        fruitsSliced = 0
        questionsAnswered = 0
        questionsCorrect = 0
        fruits.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Game Fruit

struct GameFruit: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var size: CGFloat
    var color: Color
    var rotation: Double
    var sliced: Bool = false
}

// MARK: - Fruit Game View

struct FruitGameView: View {
    let fruit: GameFruit

    var body: some View {
        ZStack {
            Circle()
                .fill(fruit.color)
                .frame(width: fruit.size, height: fruit.size)
                .shadow(color: fruit.color.opacity(0.5), radius: 8)

            if fruit.sliced {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: fruit.size + 10, height: 3)
                    .rotationEffect(.degrees(45))
            }
        }
        .rotationEffect(.degrees(fruit.rotation))
        .opacity(fruit.sliced ? 0.5 : 1.0)
        .position(x: fruit.x, y: fruit.y)
    }
}

// MARK: - Slice Game Trail View

struct SliceGameTrailView: View {
    let points: [CGPoint]

    var body: some View {
        Path { path in
            guard points.count > 1 else { return }
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(
            LinearGradient(
                colors: [.white.opacity(0), .white, .white.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
        .shadow(color: .white, radius: 5)
    }
}
