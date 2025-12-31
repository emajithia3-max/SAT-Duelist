import SwiftUI

// MARK: - Bubble Pop Game
// Tap bubbles with answers - pop correct ones before they float away!

struct BubblePopGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var bubbles: [AnswerBubble] = []
    @State private var currentQuestion: LoadedQuestion?
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var gameEnded = false
    @State private var combo: Int = 0
    @State private var popEffects: [PopEffect] = []
    @State private var timeRemaining: Double = 60
    @State private var isPaused = false

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    let bubbleSpawner = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Underwater background
                    UnderwaterBackgroundView()

                    // Bubbles
                    ForEach(bubbles) { bubble in
                        BubbleView(bubble: bubble) {
                            popBubble(bubble)
                        }
                    }

                    // Pop effects
                    ForEach(popEffects) { effect in
                        PopEffectView(effect: effect)
                    }

                    // UI Overlay
                    VStack {
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

                        // Question
                        if let question = currentQuestion {
                            Text(question.question.question)
                                .font(DesignSystem.Typography.body())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }

                        // Combo display
                        if combo > 1 {
                            Text("\(combo)x COMBO!")
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(DesignSystem.Colors.orange)
                                .shadow(color: DesignSystem.Colors.orange, radius: 10)
                        }

                        Spacer()

                        Text("POP THE CORRECT ANSWER!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.cyan.opacity(0.8))
                            .padding(.bottom, 40)
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
            guard !gameEnded && !isPaused else { return }
            updateGame()
        }
        .onReceive(bubbleSpawner) { _ in
            guard !gameEnded && !isPaused else { return }
            spawnBubbles()
        }
        .onReceive(timer) { _ in
            guard !gameEnded && !isPaused else { return }
            timeRemaining -= 0.1
            if timeRemaining <= 0 {
                endGame()
            }
        }
    }

    // MARK: - Lives Display

    private var livesDisplay: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < lives ? "heart.fill" : "heart")
                    .font(.system(size: 16))
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

    // MARK: - Timer Display

    private var timerDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .foregroundColor(timeRemaining < 10 ? DesignSystem.Colors.red : DesignSystem.Colors.cyan)
            Text(String(format: "%.0f", max(0, timeRemaining)))
                .font(DesignSystem.Typography.number())
                .foregroundColor(timeRemaining < 10 ? DesignSystem.Colors.red : DesignSystem.Colors.textPrimary)
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
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.orange)
            Text("\(score)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 24) {
            Text(timeRemaining <= 0 ? "TIME'S UP!" : "GAME OVER")
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
            spawnBubbles()
        }
    }

    private func spawnBubbles() {
        guard let question = currentQuestion else { return }

        let answers = question.question.allAnswers
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        for answer in answers {
            let isCorrect = answer == question.question.correctAnswer

            let bubble = AnswerBubble(
                id: UUID(),
                x: CGFloat.random(in: 60...(screenWidth - 60)),
                y: screenHeight + 50,
                size: CGFloat.random(in: 70...90),
                speed: CGFloat.random(in: 1.5...3.0),
                wobbleOffset: CGFloat.random(in: 0...(.pi * 2)),
                answer: answer,
                isCorrect: isCorrect,
                hue: Double.random(in: 0...1)
            )
            bubbles.append(bubble)
        }
    }

    private func updateGame() {
        let screenHeight = UIScreen.main.bounds.height

        for i in bubbles.indices.reversed() {
            // Float up
            bubbles[i].y -= bubbles[i].speed

            // Wobble
            bubbles[i].wobbleOffset += 0.05
            bubbles[i].x += sin(bubbles[i].wobbleOffset) * 0.5

            // Remove bubbles that floated off screen
            if bubbles[i].y < -100 {
                let bubble = bubbles[i]
                bubbles.remove(at: i)

                // Lose life if correct answer floated away
                if bubble.isCorrect {
                    lives -= 1
                    combo = 0
                    HapticsManager.shared.incorrectAnswer()

                    if lives <= 0 {
                        endGame()
                        return
                    }
                }
            }
        }

        // Remove old pop effects
        popEffects.removeAll { Date().timeIntervalSince($0.createdAt) > 0.5 }
    }

    private func popBubble(_ bubble: AnswerBubble) {
        guard let index = bubbles.firstIndex(where: { $0.id == bubble.id }) else { return }

        // Add pop effect
        let effect = PopEffect(id: UUID(), x: bubble.x, y: bubble.y, createdAt: Date())
        popEffects.append(effect)

        bubbles.remove(at: index)

        if bubble.isCorrect {
            HapticsManager.shared.correctAnswer()
            combo += 1
            score += 100 * combo
            _ = engine.submitAnswer(bubble.answer)

            // Clear remaining bubbles and advance
            bubbles.removeAll()
            advanceQuestion()
        } else {
            HapticsManager.shared.incorrectAnswer()
            combo = 0
            lives -= 1
            _ = engine.submitAnswer(bubble.answer)

            if lives <= 0 {
                endGame()
            }
        }
    }

    private func advanceQuestion() {
        if engine.hasMoreQuestions {
            currentQuestion = engine.nextQuestion()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                spawnBubbles()
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
        timeRemaining = 60
        bubbles.removeAll()
        popEffects.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Answer Bubble Model

struct AnswerBubble: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var speed: CGFloat
    var wobbleOffset: CGFloat
    let answer: String
    let isCorrect: Bool
    let hue: Double
}

// MARK: - Pop Effect Model

struct PopEffect: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let createdAt: Date
}

// MARK: - Bubble View

struct BubbleView: View {
    let bubble: AnswerBubble
    let onTap: () -> Void

    @State private var shimmer = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hue: bubble.hue, saturation: 0.5, brightness: 0.9).opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: bubble.size * 0.3,
                            endRadius: bubble.size * 0.6
                        )
                    )
                    .frame(width: bubble.size * 1.2, height: bubble.size * 1.2)

                // Main bubble
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hue: bubble.hue, saturation: 0.4, brightness: 1.0).opacity(0.6),
                                Color(hue: bubble.hue, saturation: 0.5, brightness: 0.8).opacity(0.4)
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: bubble.size
                        )
                    )
                    .frame(width: bubble.size, height: bubble.size)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.6), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )

                // Shine
                Circle()
                    .fill(.white.opacity(0.4))
                    .frame(width: bubble.size * 0.2, height: bubble.size * 0.2)
                    .offset(x: -bubble.size * 0.2, y: -bubble.size * 0.2)

                // Answer text
                Text(bubble.answer)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(width: bubble.size * 0.8)
            }
        }
        .buttonStyle(BubbleButtonStyle())
        .position(x: bubble.x, y: bubble.y)
    }
}

struct BubbleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Pop Effect View

struct PopEffectView: View {
    let effect: PopEffect

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(DesignSystem.Colors.cyan)
                    .frame(width: 10, height: 10)
                    .offset(x: cos(CGFloat(i) * .pi / 4) * 30 * scale,
                            y: sin(CGFloat(i) * .pi / 4) * 30 * scale)
            }
        }
        .opacity(opacity)
        .position(x: effect.x, y: effect.y)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                scale = 2.0
                opacity = 0
            }
        }
    }
}

// MARK: - Underwater Background View

struct UnderwaterBackgroundView: View {
    @State private var bubblePositions: [(x: CGFloat, y: CGFloat, size: CGFloat, speed: CGFloat)] = []

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#0a2463"),
                    Color(hex: "#1e3d59"),
                    Color(hex: "#17394d")
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Light rays
            ForEach(0..<5, id: \.self) { i in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.1), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 40, height: 500)
                    .rotationEffect(.degrees(Double(i - 2) * 10))
                    .offset(x: CGFloat(i - 2) * 80, y: -100)
            }

            // Background bubbles
            GeometryReader { geometry in
                ForEach(0..<bubblePositions.count, id: \.self) { i in
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                        .frame(width: bubblePositions[i].size)
                        .position(x: bubblePositions[i].x, y: bubblePositions[i].y)
                }
            }
        }
        .onAppear {
            let bounds = UIScreen.main.bounds
            bubblePositions = (0..<20).map { _ in
                (
                    x: CGFloat.random(in: 0...bounds.width),
                    y: CGFloat.random(in: 0...bounds.height),
                    size: CGFloat.random(in: 5...20),
                    speed: CGFloat.random(in: 0.5...2)
                )
            }
        }
    }
}
