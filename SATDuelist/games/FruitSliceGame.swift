import SwiftUI

// MARK: - Fruit Slice Game
// Fruit Ninja style - slice the correct answers, avoid wrong ones!

struct FruitSliceGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var fruits: [SliceFruit] = []
    @State private var currentQuestion: LoadedQuestion?
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var gameEnded = false
    @State private var combo: Int = 0
    @State private var sliceTrail: [CGPoint] = []
    @State private var showSlash = false
    @State private var slashPoints: (CGPoint, CGPoint) = (.zero, .zero)

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    let fruitSpawner = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

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

                    // Wood pattern overlay
                    WoodPatternView()
                        .opacity(0.1)

                    // Fruits
                    ForEach(fruits) { fruit in
                        FruitView(fruit: fruit)
                    }

                    // Slash trail
                    if showSlash {
                        SlashTrailView(start: slashPoints.0, end: slashPoints.1)
                    }

                    // Slice trail
                    SliceTrailView(points: sliceTrail)

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
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }

                        // Combo display
                        if combo > 1 {
                            Text("\(combo)x COMBO!")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(DesignSystem.Colors.orange)
                                .shadow(color: DesignSystem.Colors.orange, radius: 10)
                        }

                        Spacer()

                        Text("SLICE THE CORRECT ANSWER!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.cyan.opacity(0.8))
                            .padding(.bottom, 40)
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
                            guard !gameEnded else { return }
                            sliceTrail.append(value.location)
                            if sliceTrail.count > 20 {
                                sliceTrail.removeFirst()
                            }
                            checkSlice(at: value.location, geometry: geometry)
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
            guard !gameEnded else { return }
            updateGame()
        }
        .onReceive(fruitSpawner) { _ in
            guard !gameEnded else { return }
            spawnFruits()
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
            Text("GAME OVER")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.red)

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
        }
    }

    private func spawnFruits() {
        guard let question = currentQuestion else { return }

        let answers = question.question.allAnswers
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        for answer in answers {
            let isCorrect = answer == question.question.correctAnswer
            let startX = CGFloat.random(in: 60...(screenWidth - 60))

            let fruit = SliceFruit(
                id: UUID(),
                x: startX,
                y: screenHeight + 50,
                velocityX: CGFloat.random(in: -2...2),
                velocityY: CGFloat.random(in: -18...-14),
                answer: answer,
                isCorrect: isCorrect,
                fruitType: FruitType.allCases.randomElement() ?? .apple,
                rotation: 0
            )
            fruits.append(fruit)
        }
    }

    private func updateGame() {
        let screenHeight = UIScreen.main.bounds.height

        for i in fruits.indices.reversed() {
            // Apply physics
            fruits[i].velocityY += 0.4 // Gravity
            fruits[i].x += fruits[i].velocityX
            fruits[i].y += fruits[i].velocityY
            fruits[i].rotation += 5

            // Remove fruits that fell off screen
            if fruits[i].y > screenHeight + 100 {
                let fruit = fruits[i]
                fruits.remove(at: i)

                // Lose life if correct answer fell
                if fruit.isCorrect && !fruit.sliced {
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

    private func checkSlice(at point: CGPoint, geometry: GeometryProxy) {
        for i in fruits.indices.reversed() {
            let fruit = fruits[i]
            guard !fruit.sliced else { continue }

            let distance = sqrt(pow(point.x - fruit.x, 2) + pow(point.y - fruit.y, 2))

            if distance < 50 {
                sliceFruit(at: i, slicePoint: point)
                break
            }
        }
    }

    private func sliceFruit(at index: Int, slicePoint: CGPoint) {
        var fruit = fruits[index]
        fruit.sliced = true
        fruits[index] = fruit

        // Show slash effect
        slashPoints = (CGPoint(x: slicePoint.x - 30, y: slicePoint.y - 30),
                      CGPoint(x: slicePoint.x + 30, y: slicePoint.y + 30))
        showSlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showSlash = false
        }

        if fruit.isCorrect {
            HapticsManager.shared.correctAnswer()
            combo += 1
            score += 100 * combo
            _ = engine.submitAnswer(fruit.answer)

            // Remove after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let idx = fruits.firstIndex(where: { $0.id == fruit.id }) {
                    fruits.remove(at: idx)
                }
                advanceQuestion()
            }
        } else {
            HapticsManager.shared.incorrectAnswer()
            combo = 0
            lives -= 1
            _ = engine.submitAnswer(fruit.answer)

            if lives <= 0 {
                endGame()
            }
        }
    }

    private func advanceQuestion() {
        // Clear remaining fruits
        fruits.removeAll()

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
        lives = 3
        score = 0
        combo = 0
        fruits.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Slice Fruit Model

struct SliceFruit: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    let answer: String
    let isCorrect: Bool
    let fruitType: FruitType
    var rotation: Double
    var sliced: Bool = false
}

enum FruitType: CaseIterable {
    case apple, orange, watermelon, grape

    var color: Color {
        switch self {
        case .apple: return Color(hex: "#FF6B6B")
        case .orange: return Color(hex: "#FFA94D")
        case .watermelon: return Color(hex: "#51CF66")
        case .grape: return Color(hex: "#9775FA")
        }
    }

    var icon: String {
        switch self {
        case .apple: return "circle.fill"
        case .orange: return "circle.fill"
        case .watermelon: return "oval.fill"
        case .grape: return "circle.fill"
        }
    }
}

// MARK: - Fruit View

struct FruitView: View {
    let fruit: SliceFruit

    var body: some View {
        ZStack {
            // Fruit body
            Circle()
                .fill(fruit.fruitType.color)
                .frame(width: 70, height: 70)
                .shadow(color: fruit.fruitType.color.opacity(0.5), radius: 8)

            // Answer text
            Text(fruit.answer)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(width: 60)

            // Sliced effect
            if fruit.sliced {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 80, height: 3)
                    .rotationEffect(.degrees(45))
            }
        }
        .rotationEffect(.degrees(fruit.rotation))
        .opacity(fruit.sliced ? 0.5 : 1.0)
        .position(x: fruit.x, y: fruit.y)
    }
}

// MARK: - Slice Trail View

struct SliceTrailView: View {
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

// MARK: - Slash Trail View

struct SlashTrailView: View {
    let start: CGPoint
    let end: CGPoint

    var body: some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            LinearGradient(
                colors: [.white.opacity(0), DesignSystem.Colors.cyan, .white.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 6, lineCap: .round)
        )
        .shadow(color: DesignSystem.Colors.cyan, radius: 10)
    }
}

// MARK: - Wood Pattern View

struct WoodPatternView: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(0..<Int(geometry.size.height / 40), id: \.self) { _ in
                    Rectangle()
                        .fill(Color(hex: "#3D2914"))
                        .frame(height: 40)
                        .overlay(
                            Rectangle()
                                .fill(Color(hex: "#2A1D0D"))
                                .frame(height: 2),
                            alignment: .bottom
                        )
                }
            }
        }
    }
}
