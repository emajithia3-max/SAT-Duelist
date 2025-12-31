import SwiftUI

// MARK: - Flappy Scholar Game
// Tap to fly, choose the correct answer gate to pass through!

struct FlappyScholarGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var birdY: CGFloat = 400
    @State private var birdVelocity: CGFloat = 0
    @State private var gates: [AnswerGate] = []
    @State private var currentQuestion: LoadedQuestion?
    @State private var score: Int = 0
    @State private var gameEnded = false
    @State private var gameStarted = false
    @State private var birdRotation: Double = 0
    @State private var scrollOffset: CGFloat = 0

    let gravity: CGFloat = 0.6
    let jumpVelocity: CGFloat = -12
    let scrollSpeed: CGFloat = 3
    let gateSpacing: CGFloat = 400
    let gateWidth: CGFloat = 100

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Sky background
                    LinearGradient(
                        colors: [
                            Color(hex: "#1a1a2e"),
                            Color(hex: "#16213e"),
                            Color(hex: "#0f3460")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Stars
                    StarsBackgroundView()

                    // Ground
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(DesignSystem.Colors.elevated)
                            .frame(height: 80)
                            .overlay(
                                Rectangle()
                                    .fill(DesignSystem.Colors.primary.opacity(0.3))
                                    .frame(height: 4),
                                alignment: .top
                            )
                    }

                    // Gates
                    ForEach(gates) { gate in
                        GateView(gate: gate, scrollOffset: scrollOffset, screenHeight: geometry.size.height)
                    }

                    // Bird
                    BirdView(rotation: birdRotation)
                        .position(x: 100, y: birdY)

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

                        // Question
                        if let question = currentQuestion, gameStarted {
                            Text(question.question.question)
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 20)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
                                )
                                .padding(.top, 10)
                        }

                        Spacer()

                        // Tap to start
                        if !gameStarted && !gameEnded {
                            VStack(spacing: 12) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(DesignSystem.Colors.cyan)

                                Text("TAP TO FLY")
                                    .font(DesignSystem.Typography.button())
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                Text("Fly through the correct answer!")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textMuted)
                            }
                            .padding(.bottom, 200)
                        }
                    }

                    // Game over
                    if gameEnded {
                        gameOverOverlay
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !gameEnded {
                        flap()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await startGame()
        }
        .onReceive(gameLoop) { _ in
            guard !gameEnded && gameStarted else { return }
            updateGame()
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
                StatRow(icon: "percent", label: "Accuracy", value: "\(Int(engine.accuracy))%", color: DesignSystem.Colors.blue)
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
            spawnGate(for: question, atX: 500)
        }

        birdY = UIScreen.main.bounds.height / 2
        birdVelocity = 0
    }

    private func spawnGate(for question: LoadedQuestion, atX x: CGFloat) {
        let answers = question.question.allAnswers
        let screenHeight = UIScreen.main.bounds.height

        // Create vertical slots for answers
        let slotHeight: CGFloat = 100
        let totalHeight = CGFloat(answers.count) * slotHeight
        let startY = (screenHeight - 80 - totalHeight) / 2

        for (index, answer) in answers.enumerated() {
            let gate = AnswerGate(
                id: UUID(),
                x: x,
                y: startY + CGFloat(index) * slotHeight + slotHeight / 2,
                answer: answer,
                isCorrect: answer == question.question.correctAnswer,
                slotHeight: slotHeight
            )
            gates.append(gate)
        }
    }

    private func flap() {
        if !gameStarted {
            gameStarted = true
        }
        HapticsManager.shared.selectionChanged()
        birdVelocity = jumpVelocity
    }

    private func updateGame() {
        let screenHeight = UIScreen.main.bounds.height

        // Apply gravity
        birdVelocity += gravity
        birdY += birdVelocity

        // Update bird rotation based on velocity
        birdRotation = Double(birdVelocity * 3)
        birdRotation = max(-30, min(90, birdRotation))

        // Scroll gates
        scrollOffset += scrollSpeed

        // Check bounds
        if birdY < 50 || birdY > screenHeight - 100 {
            endGame()
            return
        }

        // Check gate collisions
        checkGateCollisions()

        // Remove passed gates and spawn new ones
        gates.removeAll { gate in
            gate.x - scrollOffset < -gateWidth
        }

        // Spawn new gate when needed
        if let lastGate = gates.last {
            if lastGate.x - scrollOffset < UIScreen.main.bounds.width {
                advanceQuestion()
            }
        }
    }

    private func checkGateCollisions() {
        let birdX: CGFloat = 100
        let birdRadius: CGFloat = 20

        for gate in gates {
            let gateScreenX = gate.x - scrollOffset

            // Check if bird is passing through gate area
            if gateScreenX > birdX - birdRadius && gateScreenX < birdX + birdRadius + gateWidth {
                let inSlot = birdY > gate.y - gate.slotHeight/2 && birdY < gate.y + gate.slotHeight/2

                if inSlot {
                    if gate.isCorrect && !gate.passed {
                        // Mark as passed
                        if let index = gates.firstIndex(where: { $0.id == gate.id }) {
                            gates[index].passed = true
                            HapticsManager.shared.correctAnswer()
                            score += 100
                        }
                    } else if !gate.isCorrect {
                        HapticsManager.shared.incorrectAnswer()
                        endGame()
                        return
                    }
                }
            }
        }
    }

    private func advanceQuestion() {
        // Remove current gates
        let rightmostX = gates.map { $0.x }.max() ?? scrollOffset

        if engine.hasMoreQuestions {
            if let question = engine.nextQuestion() {
                currentQuestion = question
                spawnGate(for: question, atX: rightmostX + gateSpacing)
            }
        } else {
            // Keep spawning with old questions or end
            if let question = currentQuestion {
                spawnGate(for: question, atX: rightmostX + gateSpacing)
            }
        }
    }

    private func endGame() {
        gameEnded = true
        HapticsManager.shared.gameTransition()
    }

    private func resetGame() {
        gameEnded = false
        gameStarted = false
        score = 0
        scrollOffset = 0
        gates.removeAll()
        birdVelocity = 0
        birdRotation = 0
        Task {
            await startGame()
        }
    }
}

// MARK: - Answer Gate Model

struct AnswerGate: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let answer: String
    let isCorrect: Bool
    let slotHeight: CGFloat
    var passed: Bool = false
}

// MARK: - Gate View

struct GateView: View {
    let gate: AnswerGate
    let scrollOffset: CGFloat
    let screenHeight: CGFloat

    var body: some View {
        let screenX = gate.x - scrollOffset

        ZStack {
            // Gate frame
            RoundedRectangle(cornerRadius: 12)
                .fill(gate.passed ? DesignSystem.Colors.cyan.opacity(0.3) : DesignSystem.Colors.cardBackground)
                .frame(width: 90, height: gate.slotHeight - 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            gate.passed ? DesignSystem.Colors.cyan : DesignSystem.Colors.primary,
                            lineWidth: 3
                        )
                )

            // Answer text
            Text(gate.answer)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(gate.passed ? DesignSystem.Colors.cyan : DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(8)
        }
        .position(x: screenX + 45, y: gate.y)
        .opacity(screenX > -100 && screenX < UIScreen.main.bounds.width + 100 ? 1 : 0)
    }
}

// MARK: - Bird View

struct BirdView: View {
    let rotation: Double

    @State private var wingUp = false

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(DesignSystem.Colors.orange.opacity(0.3))
                .frame(width: 50, height: 50)
                .blur(radius: 8)

            // Body
            Ellipse()
                .fill(DesignSystem.Colors.orange)
                .frame(width: 40, height: 35)

            // Wing
            Ellipse()
                .fill(DesignSystem.Colors.orange.opacity(0.8))
                .frame(width: 20, height: 12)
                .offset(x: -5, y: wingUp ? -10 : 5)

            // Eye
            Circle()
                .fill(.white)
                .frame(width: 12, height: 12)
                .offset(x: 10, y: -5)

            Circle()
                .fill(.black)
                .frame(width: 6, height: 6)
                .offset(x: 12, y: -5)

            // Beak
            Triangle()
                .fill(Color.yellow)
                .frame(width: 15, height: 10)
                .offset(x: 25, y: 2)
        }
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
                wingUp = true
            }
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Stars Background

struct StarsBackgroundView: View {
    @State private var stars: [(x: CGFloat, y: CGFloat, size: CGFloat)] = []

    var body: some View {
        Canvas { context, size in
            for star in stars {
                let rect = CGRect(x: star.x, y: star.y, width: star.size, height: star.size)
                context.fill(Circle().path(in: rect), with: .color(.white.opacity(0.7)))
            }
        }
        .onAppear {
            let bounds = UIScreen.main.bounds
            stars = (0..<60).map { _ in
                (
                    x: CGFloat.random(in: 0...bounds.width),
                    y: CGFloat.random(in: 0...bounds.height * 0.7),
                    size: CGFloat.random(in: 1...2)
                )
            }
        }
    }
}
