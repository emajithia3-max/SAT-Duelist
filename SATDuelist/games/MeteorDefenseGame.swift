import SwiftUI

// MARK: - Meteor Defense Game
// Space shooter where meteors approach - answer questions to fire lasers!
// Correct answers destroy meteors, wrong answers let them through

struct MeteorDefenseGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // MARK: - Game State
    @State private var currentQuestion: LoadedQuestion?
    @State private var selectedAnswer: String?
    @State private var answerResult: AnswerResult?
    @State private var showResult = false
    @State private var isCardPresented = false
    @State private var shakeTrigger = 0
    @State private var popTrigger = 0
    @State private var showGlow = false
    @State private var showError = false
    @State private var gameEnded = false
    @State private var sessionResult: SessionResult?
    @State private var sprAnswer = ""

    // Meteor Defense specific state
    @State private var meteors: [Meteor] = []
    @State private var laserFiring = false
    @State private var explosions: [MeteorDefenseExplosion] = []
    @State private var shieldHealth: Int = 3
    @State private var score: Int = 0
    @State private var meteorsDestroyed: Int = 0
    @State private var difficultyLevel: Int = 1

    // Answer options for MCQ
    @State private var answerOptions: [String] = []

    // Timer for meteor spawning
    let meteorTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    let gameLoop = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        CinematicContainer(
            vignette: true,
            bloom: true,
            motionBlur: laserFiring,
            grain: false,
            motionBlurIntensity: 0.3
        ) {
            GeometryReader { geometry in
                ZStack {
                    // Starfield background
                    StarfieldView()

                    // Meteors
                    ForEach(meteors) { meteor in
                        MeteorView(meteor: meteor)
                    }

                    // Explosions
                    ForEach(explosions) { explosion in
                        MeteorDefenseExplosionView(explosion: explosion)
                    }

                    // Laser beam when firing
                    if laserFiring {
                        LaserBeamView()
                    }

                    // Player ship at bottom
                    PlayerShipView()
                        .position(x: geometry.size.width / 2, y: geometry.size.height - 100)

                    // Shield indicator
                    VStack {
                        HStack {
                            shieldIndicator
                            Spacer()
                            scoreDisplay
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)

                        Spacer()
                    }

                    // Question overlay
                    VStack {
                        Spacer()

                        if let question = currentQuestion, !gameEnded {
                            questionOverlay(question, geometry: geometry)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    // Close button
                    VStack {
                        HStack {
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        Spacer()
                    }

                    // Game Over overlay
                    if gameEnded {
                        gameOverOverlay
                    }
                }
            }
            .ignoresSafeArea()
        }
        .task {
            await startGame()
        }
        .onReceive(meteorTimer) { _ in
            if !gameEnded && currentQuestion != nil {
                spawnMeteor()
            }
        }
        .onReceive(gameLoop) { _ in
            updateGame()
        }
    }

    // MARK: - Shield Indicator

    private var shieldIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < shieldHealth ? "shield.fill" : "shield")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(index < shieldHealth ? DesignSystem.Colors.cyan : DesignSystem.Colors.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.8))
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
                .fill(DesignSystem.Colors.cardBackground.opacity(0.8))
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
                        .fill(DesignSystem.Colors.elevated.opacity(0.8))
                )
        }
    }

    // MARK: - Question Overlay

    private func questionOverlay(_ question: LoadedQuestion, geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            // Compact question text
            Text(question.question.question)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 16)

            // Answer buttons in 2x2 grid for MCQ
            if question.question.isMultipleChoice {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(answerOptions, id: \.self) { answer in
                        CompactAnswerButton(
                            answer: answer,
                            isSelected: selectedAnswer == answer,
                            isCorrect: showResult ? (answer == question.question.correctAnswer ? true : (selectedAnswer == answer ? false : nil)) : nil,
                            isDisabled: showResult
                        ) {
                            selectAnswer(answer)
                        }
                    }
                }
            } else {
                // SPR input
                HStack(spacing: 12) {
                    SPRInputField(text: $sprAnswer, placeholder: "Answer") {
                        if !sprAnswer.isEmpty {
                            submitSPRAnswer()
                        }
                    }
                    .disabled(showResult)

                    if !showResult && !sprAnswer.isEmpty {
                        Button {
                            submitSPRAnswer()
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.cardBackground.opacity(0.95))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 24) {
            Text("GAME OVER")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.red)

            VStack(spacing: 16) {
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "flame.fill", label: "Meteors Destroyed", value: "\(meteorsDestroyed)", color: DesignSystem.Colors.red)
                StatRow(icon: "checkmark.circle.fill", label: "Questions Correct", value: "\(engine.correctAnswers)", color: DesignSystem.Colors.cyan)
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

            Button {
                dismiss()
            } label: {
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

        HapticsManager.shared.gameTransition()

        if let question = engine.startSession() {
            currentQuestion = question
            answerOptions = question.question.allAnswers

            withAnimation(DesignSystem.Animation.spring) {
                isCardPresented = true
            }
        }

        // Spawn initial meteor
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            spawnMeteor()
        }
    }

    private func spawnMeteor() {
        guard !gameEnded else { return }

        let meteor = Meteor(
            id: UUID(),
            x: CGFloat.random(in: 50...350),
            y: -50,
            speed: Double.random(in: 1.5...3.0) + Double(difficultyLevel) * 0.3,
            size: CGFloat.random(in: 30...50)
        )
        withAnimation {
            meteors.append(meteor)
        }
    }

    private func updateGame() {
        guard !gameEnded else { return }

        // Move meteors down
        for i in meteors.indices.reversed() {
            meteors[i].y += meteors[i].speed

            // Check if meteor hit the bottom
            if meteors[i].y > UIScreen.main.bounds.height - 150 {
                meteorHitShield(at: i)
            }
        }

        // Remove old explosions
        explosions.removeAll { $0.createdAt.timeIntervalSinceNow < -0.5 }

        // Increase difficulty over time
        if meteorsDestroyed > 0 && meteorsDestroyed % 5 == 0 {
            difficultyLevel = min(5, meteorsDestroyed / 5 + 1)
        }
    }

    private func meteorHitShield(at index: Int) {
        guard index < meteors.count else { return }

        let meteor = meteors[index]
        meteors.remove(at: index)

        shieldHealth -= 1
        HapticsManager.shared.incorrectAnswer()

        if shieldHealth <= 0 {
            endGame()
        }
    }

    private func selectAnswer(_ answer: String) {
        guard !showResult else { return }

        HapticsManager.shared.answerTap()
        selectedAnswer = answer
        submitAnswer(answer)
    }

    private func submitSPRAnswer() {
        guard !showResult, !sprAnswer.isEmpty else { return }
        HapticsManager.shared.answerTap()
        submitAnswer(sprAnswer)
    }

    private func submitAnswer(_ answer: String) {
        let result = engine.submitAnswer(answer)
        answerResult = result

        if result.isCorrect {
            HapticsManager.shared.correctAnswer()
            showGlow = true
            popTrigger += 1

            // Fire laser and destroy nearest meteor
            fireLaser()
        } else {
            HapticsManager.shared.incorrectAnswer()
            showError = true
            shakeTrigger += 1
        }

        showResult = true

        // Quick advance for action game
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            advanceToNext()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showGlow = false
            showError = false
        }
    }

    private func fireLaser() {
        laserFiring = true

        // Destroy the lowest meteor (closest to ship)
        if let index = meteors.indices.max(by: { meteors[$0].y < meteors[$1].y }) {
            let meteor = meteors[index]

            // Create explosion
            let explosion = MeteorDefenseExplosion(id: UUID(), x: meteor.x, y: meteor.y, createdAt: Date())
            explosions.append(explosion)

            // Remove meteor
            meteors.remove(at: index)

            // Update score
            meteorsDestroyed += 1
            score += 100 * difficultyLevel
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            laserFiring = false
        }
    }

    private func advanceToNext() {
        guard !gameEnded else { return }

        if engine.hasMoreQuestions {
            selectedAnswer = nil
            answerResult = nil
            showResult = false
            sprAnswer = ""

            if let question = engine.nextQuestion() {
                currentQuestion = question
                answerOptions = question.question.allAnswers
            }
        } else {
            endGame()
        }
    }

    private func endGame() {
        gameEnded = true
        sessionResult = engine.endSession()
        HapticsManager.shared.gameTransition()
    }

    private func resetGame() {
        meteors.removeAll()
        explosions.removeAll()
        shieldHealth = 3
        score = 0
        meteorsDestroyed = 0
        difficultyLevel = 1
        gameEnded = false
        sessionResult = nil
        selectedAnswer = nil
        answerResult = nil
        showResult = false
        sprAnswer = ""

        Task {
            await startGame()
        }
    }
}

// MARK: - Supporting Types

struct Meteor: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var speed: Double
    var size: CGFloat
}

struct MeteorDefenseExplosion: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let createdAt: Date
}

// MARK: - Starfield Background

struct StarfieldView: View {
    @State private var stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []

    var body: some View {
        Canvas { context, size in
            for star in stars {
                let rect = CGRect(x: star.x, y: star.y, width: star.size, height: star.size)
                context.fill(
                    Circle().path(in: rect),
                    with: .color(.white.opacity(star.opacity))
                )
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#0a0a15"),
                    Color(hex: "#15152a"),
                    DesignSystem.Colors.primaryBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            generateStars()
        }
    }

    private func generateStars() {
        let bounds = UIScreen.main.bounds
        stars = (0..<100).map { _ in
            (
                x: CGFloat.random(in: 0...bounds.width),
                y: CGFloat.random(in: 0...bounds.height),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...1.0)
            )
        }
    }
}

// MARK: - Meteor View

struct MeteorView: View {
    let meteor: Meteor

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [DesignSystem.Colors.orange, DesignSystem.Colors.red.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: meteor.size
                    )
                )
                .frame(width: meteor.size * 2, height: meteor.size * 2)

            // Core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [DesignSystem.Colors.orange, DesignSystem.Colors.red],
                        center: .center,
                        startRadius: 0,
                        endRadius: meteor.size / 2
                    )
                )
                .frame(width: meteor.size, height: meteor.size)
        }
        .position(x: meteor.x, y: meteor.y)
    }
}

// MARK: - Explosion View

struct MeteorDefenseExplosionView: View {
    let explosion: MeteorDefenseExplosion
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white, DesignSystem.Colors.orange, DesignSystem.Colors.red.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 40
                )
            )
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(x: explosion.x, y: explosion.y)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    scale = 2.0
                    opacity = 0
                }
            }
    }
}

// MARK: - Laser Beam View

struct LaserBeamView: View {
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [DesignSystem.Colors.cyan.opacity(0), DesignSystem.Colors.cyan, DesignSystem.Colors.cyan.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 6)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .blur(radius: 2)
        }
    }
}

// MARK: - Player Ship View

struct PlayerShipView: View {
    var body: some View {
        ZStack {
            // Ship glow
            Ellipse()
                .fill(DesignSystem.Colors.primary.opacity(0.3))
                .frame(width: 80, height: 30)
                .blur(radius: 10)

            // Ship body
            Image(systemName: "airplane")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(DesignSystem.Colors.primary)
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Compact Answer Button

struct CompactAnswerButton: View {
    let answer: String
    let isSelected: Bool
    let isCorrect: Bool?
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(answer)
                .font(DesignSystem.Typography.caption())
                .foregroundColor(textColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                )
        }
        .disabled(isDisabled)
    }

    private var textColor: Color {
        if let correct = isCorrect {
            return correct ? .white : .white
        }
        return isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary
    }

    private var backgroundColor: Color {
        if let correct = isCorrect {
            return correct ? DesignSystem.Colors.cyan.opacity(0.3) : DesignSystem.Colors.red.opacity(0.3)
        }
        return isSelected ? DesignSystem.Colors.elevated : DesignSystem.Colors.cardBackground
    }

    private var borderColor: Color {
        if let correct = isCorrect {
            return correct ? DesignSystem.Colors.cyan : DesignSystem.Colors.red
        }
        return isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBorder
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}
