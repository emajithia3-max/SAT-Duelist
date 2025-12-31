import SwiftUI

// MARK: - Flappy Scholar Game
// Classic flappy bird - fly through gaps, question gates appear every few obstacles

struct FlappyScholarGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var birdY: CGFloat = 400
    @State private var birdVelocity: CGFloat = 0
    @State private var pipes: [FlappyPipe] = []
    @State private var score: Int = 0
    @State private var pipesPassed: Int = 0
    @State private var gameEnded = false
    @State private var gameStarted = false
    @State private var birdRotation: Double = 0

    // Question state
    @State private var showQuestion = false
    @State private var currentQuestion: LoadedQuestion?
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var questionsAnswered: Int = 0
    @State private var questionsCorrect: Int = 0

    let gravity: CGFloat = 0.6
    let jumpVelocity: CGFloat = -10
    let pipeSpeed: CGFloat = 3
    let pipeSpacing: CGFloat = 280
    let gapHeight: CGFloat = 180
    let questionInterval: Int = 4 // Question every 4 pipes

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    let pipeSpawner = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Sky background
                    LinearGradient(
                        colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e"), Color(hex: "#0f3460")],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Stars
                    StarsView()

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

                    // Pipes
                    ForEach(pipes) { pipe in
                        PipeView(pipe: pipe, gapHeight: gapHeight, screenHeight: geometry.size.height)
                    }

                    // Bird
                    FlappyBirdView(rotation: birdRotation)
                        .position(x: 100, y: birdY)

                    // UI Overlay
                    VStack {
                        HStack {
                            scoreDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)

                        Spacer()

                        if !gameStarted && !gameEnded {
                            VStack(spacing: 16) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(DesignSystem.Colors.cyan)

                                Text("TAP TO FLY")
                                    .font(DesignSystem.Typography.button())
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                            .padding(.bottom, 200)
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
                    if !gameEnded && !showQuestion {
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
            guard !gameEnded && gameStarted && !showQuestion else { return }
            updateGame()
        }
        .onReceive(pipeSpawner) { _ in
            guard !gameEnded && gameStarted && !showQuestion else { return }
            spawnPipe()
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

    // MARK: - Question Overlay

    private func questionOverlay(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(DesignSystem.Colors.orange)
                Text("QUESTION GATE!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.orange)
            }

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
                StatRow(icon: "arrow.right", label: "Pipes Passed", value: "\(pipesPassed)", color: DesignSystem.Colors.cyan)
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

        birdY = UIScreen.main.bounds.height / 2
        birdVelocity = 0
    }

    private func flap() {
        if !gameStarted {
            gameStarted = true
        }
        HapticsManager.shared.selectionChanged()
        birdVelocity = jumpVelocity
    }

    private func spawnPipe() {
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width

        let minGapY = gapHeight / 2 + 100
        let maxGapY = screenHeight - 80 - gapHeight / 2 - 50
        let gapY = CGFloat.random(in: minGapY...maxGapY)

        let pipe = FlappyPipe(
            id: UUID(),
            x: screenWidth + 50,
            gapY: gapY,
            passed: false
        )
        pipes.append(pipe)
    }

    private func updateGame() {
        let screenHeight = UIScreen.main.bounds.height

        // Apply physics
        birdVelocity += gravity
        birdY += birdVelocity

        // Bird rotation
        birdRotation = Double(birdVelocity * 3)
        birdRotation = max(-30, min(90, birdRotation))

        // Check bounds
        if birdY < 30 || birdY > screenHeight - 100 {
            endGame()
            return
        }

        // Move pipes and check collisions
        for i in pipes.indices.reversed() {
            pipes[i].x -= pipeSpeed

            // Check if passed
            if !pipes[i].passed && pipes[i].x < 100 - 30 {
                pipes[i].passed = true
                pipesPassed += 1
                score += 10
                HapticsManager.shared.selectionChanged()

                // Trigger question every few pipes
                if pipesPassed % questionInterval == 0 {
                    triggerQuestion()
                }
            }

            // Check collision
            let pipeWidth: CGFloat = 60
            let birdRadius: CGFloat = 15

            if pipes[i].x > 100 - pipeWidth/2 - birdRadius &&
               pipes[i].x < 100 + pipeWidth/2 + birdRadius {

                let gapTop = pipes[i].gapY - gapHeight/2
                let gapBottom = pipes[i].gapY + gapHeight/2

                if birdY - birdRadius < gapTop || birdY + birdRadius > gapBottom {
                    endGame()
                    return
                }
            }

            // Remove off-screen pipes
            if pipes[i].x < -100 {
                pipes.remove(at: i)
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
            score += 50
        } else {
            HapticsManager.shared.incorrectAnswer()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showQuestion = false

            if !isCorrect {
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
        gameStarted = false
        showQuestion = false
        score = 0
        pipesPassed = 0
        questionsAnswered = 0
        questionsCorrect = 0
        pipes.removeAll()
        birdVelocity = 0
        birdRotation = 0
        Task {
            await startGame()
        }
    }
}

// MARK: - Flappy Pipe

struct FlappyPipe: Identifiable {
    let id: UUID
    var x: CGFloat
    let gapY: CGFloat
    var passed: Bool
}

// MARK: - Pipe View

struct PipeView: View {
    let pipe: FlappyPipe
    let gapHeight: CGFloat
    let screenHeight: CGFloat

    var body: some View {
        let pipeWidth: CGFloat = 60
        let topPipeHeight = pipe.gapY - gapHeight / 2
        let bottomPipeY = pipe.gapY + gapHeight / 2

        ZStack {
            // Top pipe
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#2ECC71"), Color(hex: "#27AE60")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: pipeWidth, height: topPipeHeight)

                Rectangle()
                    .fill(Color(hex: "#27AE60"))
                    .frame(width: pipeWidth + 10, height: 30)
            }
            .position(x: pipe.x, y: topPipeHeight / 2)

            // Bottom pipe
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color(hex: "#27AE60"))
                    .frame(width: pipeWidth + 10, height: 30)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#2ECC71"), Color(hex: "#27AE60")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: pipeWidth, height: screenHeight - bottomPipeY - 80)
            }
            .position(x: pipe.x, y: bottomPipeY + (screenHeight - bottomPipeY - 80) / 2 + 15)
        }
    }
}

// MARK: - Flappy Bird View

struct FlappyBirdView: View {
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
                .frame(width: 40, height: 32)

            // Wing
            Ellipse()
                .fill(DesignSystem.Colors.orange.opacity(0.8))
                .frame(width: 18, height: 10)
                .offset(x: -5, y: wingUp ? -8 : 4)

            // Eye
            Circle()
                .fill(.white)
                .frame(width: 12, height: 12)
                .offset(x: 10, y: -4)

            Circle()
                .fill(.black)
                .frame(width: 6, height: 6)
                .offset(x: 12, y: -4)

            // Beak
            Triangle()
                .fill(Color.yellow)
                .frame(width: 14, height: 10)
                .offset(x: 24, y: 2)
        }
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                wingUp = true
            }
        }
    }
}

// MARK: - Stars View

struct StarsView: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<50, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(Double.random(in: 0.3...0.8)))
                    .frame(width: CGFloat.random(in: 1...2))
                    .position(
                        x: CGFloat(i * 8 % Int(geometry.size.width)),
                        y: CGFloat(i * 17 % Int(geometry.size.height * 0.7))
                    )
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
