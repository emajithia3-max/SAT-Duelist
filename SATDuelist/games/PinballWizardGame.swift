import SwiftUI

// MARK: - Pinball Wizard Game
// Classic pinball - hit bumpers to score! Periodic questions pause the game.

struct PinballWizardGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var ballPosition: CGPoint = CGPoint(x: 350, y: 600)
    @State private var ballVelocity: CGPoint = CGPoint(x: 0, y: 0)
    @State private var bumpers: [PinballBumper] = []
    @State private var score: Int = 0
    @State private var ballsRemaining: Int = 3
    @State private var gameEnded = false
    @State private var ballLaunched = false
    @State private var launchPower: CGFloat = 0
    @State private var isCharging = false
    @State private var leftFlipperUp = false
    @State private var rightFlipperUp = false
    @State private var hitEffects: [HitEffect] = []
    @State private var bumperHits: Int = 0

    // Question state
    @State private var showQuestion = false
    @State private var currentQuestion: LoadedQuestion?
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var questionsAnswered: Int = 0
    @State private var questionsCorrect: Int = 0

    let ballRadius: CGFloat = 12
    let gravity: CGFloat = 0.15
    let friction: CGFloat = 0.995
    let bumperBounciness: CGFloat = 8
    let questionInterval: Int = 5 // Question every 5 bumper hits

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Pinball table background
                    PinballTableView()

                    // Bumpers
                    ForEach(bumpers) { bumper in
                        PinballBumperView(bumper: bumper)
                    }

                    // Hit effects
                    ForEach(hitEffects) { effect in
                        HitEffectView(effect: effect)
                    }

                    // Ball
                    if ballLaunched && !showQuestion {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white, Color(hex: "#C0C0C0")],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: ballRadius
                                )
                            )
                            .frame(width: ballRadius * 2, height: ballRadius * 2)
                            .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                            .position(ballPosition)
                    }

                    // Flippers
                    FlipperView(isLeft: true, isUp: leftFlipperUp)
                        .position(x: 120, y: geometry.size.height - 140)

                    FlipperView(isLeft: false, isUp: rightFlipperUp)
                        .position(x: geometry.size.width - 120, y: geometry.size.height - 140)

                    // Launch lane
                    if !ballLaunched && !showQuestion {
                        LaunchLaneView(power: launchPower, isCharging: isCharging)
                            .position(x: geometry.size.width - 30, y: geometry.size.height - 200)
                    }

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            ballsDisplay
                            Spacer()
                            hitsDisplay
                            Spacer()
                            scoreDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)

                        Spacer()

                        // Controls hint
                        if !showQuestion && !gameEnded {
                            if !ballLaunched {
                                Text("HOLD & RELEASE TO LAUNCH")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(DesignSystem.Colors.orange)
                                    .padding(.bottom, 20)
                            } else {
                                Text("TAP SIDES TO FLIP")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.textMuted)
                                    .padding(.bottom, 20)
                            }
                        }
                    }

                    // Flipper touch areas
                    if !showQuestion {
                        HStack(spacing: 0) {
                            // Left flipper area
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            if ballLaunched {
                                                leftFlipperUp = true
                                                HapticsManager.shared.selectionChanged()
                                            }
                                        }
                                        .onEnded { _ in
                                            leftFlipperUp = false
                                        }
                                )

                            // Right flipper area
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            if ballLaunched {
                                                rightFlipperUp = true
                                                HapticsManager.shared.selectionChanged()
                                            }
                                        }
                                        .onEnded { _ in
                                            rightFlipperUp = false
                                        }
                                )
                        }
                        .opacity(0.01)
                    }

                    // Launch gesture area
                    if !ballLaunched && !showQuestion && !gameEnded {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                LongPressGesture(minimumDuration: 0.01)
                                    .onChanged { _ in
                                        isCharging = true
                                    }
                                    .sequenced(before: DragGesture(minimumDistance: 0))
                                    .onEnded { _ in
                                        launchBall()
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { _ in
                                        if isCharging {
                                            launchBall()
                                        }
                                    }
                            )
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

    // MARK: - Balls Display

    private var ballsDisplay: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < ballsRemaining ? Color(hex: "#C0C0C0") : DesignSystem.Colors.textMuted)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Hits Display

    private var hitsDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.cyan)
            Text("\(bumperHits)")
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
            Text("GAME OVER")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.red)

            VStack(spacing: 16) {
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "circle.circle.fill", label: "Bumper Hits", value: "\(bumperHits)", color: DesignSystem.Colors.cyan)
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
        setupBumpers()
    }

    private func setupBumpers() {
        bumpers.removeAll()

        let screenWidth = UIScreen.main.bounds.width

        let positions: [(x: CGFloat, y: CGFloat)] = [
            (screenWidth * 0.3, 220),
            (screenWidth * 0.7, 220),
            (screenWidth * 0.5, 280),
            (screenWidth * 0.2, 350),
            (screenWidth * 0.5, 380),
            (screenWidth * 0.8, 350)
        ]

        let colors: [Color] = [
            DesignSystem.Colors.cyan,
            DesignSystem.Colors.orange,
            DesignSystem.Colors.primary,
            Color(hex: "#FF6B6B"),
            Color(hex: "#51CF66"),
            Color(hex: "#9775FA")
        ]

        for (index, position) in positions.enumerated() {
            let bumper = PinballBumper(
                id: UUID(),
                x: position.x,
                y: position.y,
                radius: 30,
                color: colors[index % colors.count],
                isLit: false
            )
            bumpers.append(bumper)
        }
    }

    private func launchBall() {
        isCharging = false
        ballLaunched = true
        let screenWidth = UIScreen.main.bounds.width

        ballPosition = CGPoint(x: screenWidth - 30, y: 500)
        ballVelocity = CGPoint(x: CGFloat.random(in: -3 ... -1), y: -15 - launchPower * 0.1)
        launchPower = 0

        HapticsManager.shared.buttonPress()
    }

    private func updateGame() {
        guard ballLaunched else {
            if isCharging {
                launchPower = min(100, launchPower + 2)
            }
            return
        }

        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        // Apply physics
        ballVelocity.y += gravity
        ballVelocity.x *= friction
        ballVelocity.y *= friction

        ballPosition.x += ballVelocity.x
        ballPosition.y += ballVelocity.y

        // Wall bounces
        if ballPosition.x < ballRadius + 20 {
            ballPosition.x = ballRadius + 20
            ballVelocity.x = abs(ballVelocity.x) * 0.8
        }
        if ballPosition.x > screenWidth - ballRadius - 20 {
            ballPosition.x = screenWidth - ballRadius - 20
            ballVelocity.x = -abs(ballVelocity.x) * 0.8
        }
        if ballPosition.y < ballRadius + 120 {
            ballPosition.y = ballRadius + 120
            ballVelocity.y = abs(ballVelocity.y) * 0.8
        }

        // Check bumper collisions
        for i in bumpers.indices {
            let dx = ballPosition.x - bumpers[i].x
            let dy = ballPosition.y - bumpers[i].y
            let distance = sqrt(dx*dx + dy*dy)

            if distance < ballRadius + bumpers[i].radius {
                // Bounce off bumper
                let angle = atan2(dy, dx)
                ballVelocity.x = cos(angle) * bumperBounciness
                ballVelocity.y = sin(angle) * bumperBounciness

                // Add some randomness
                ballVelocity.x += CGFloat.random(in: -1...1)
                ballVelocity.y += CGFloat.random(in: -1...1)

                hitBumper(at: i)
                break
            }
        }

        // Check flipper collisions
        let flipperY = screenHeight - 140
        let flipperWidth: CGFloat = 80
        let flipperHeight: CGFloat = 15

        // Left flipper
        if leftFlipperUp {
            let leftFlipperX: CGFloat = 120
            if ballPosition.y > flipperY - flipperHeight &&
               ballPosition.y < flipperY + flipperHeight &&
               ballPosition.x > leftFlipperX - flipperWidth/2 &&
               ballPosition.x < leftFlipperX + flipperWidth/2 {
                ballVelocity.y = -abs(ballVelocity.y) - 5
                ballVelocity.x += 3
                HapticsManager.shared.selectionChanged()
            }
        }

        // Right flipper
        if rightFlipperUp {
            let rightFlipperX = screenWidth - 120
            if ballPosition.y > flipperY - flipperHeight &&
               ballPosition.y < flipperY + flipperHeight &&
               ballPosition.x > rightFlipperX - flipperWidth/2 &&
               ballPosition.x < rightFlipperX + flipperWidth/2 {
                ballVelocity.y = -abs(ballVelocity.y) - 5
                ballVelocity.x -= 3
                HapticsManager.shared.selectionChanged()
            }
        }

        // Ball lost
        if ballPosition.y > screenHeight - 80 {
            loseBall()
        }

        // Clean up effects
        hitEffects.removeAll { Date().timeIntervalSince($0.createdAt) > 0.3 }
    }

    private func hitBumper(at index: Int) {
        let bumper = bumpers[index]

        // Add hit effect
        let effect = HitEffect(id: UUID(), x: bumper.x, y: bumper.y, createdAt: Date())
        hitEffects.append(effect)

        // Light up bumper
        bumpers[index].isLit = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if index < bumpers.count {
                bumpers[index].isLit = false
            }
        }

        HapticsManager.shared.selectionChanged()
        score += 100
        bumperHits += 1

        // Trigger question periodically
        if bumperHits % questionInterval == 0 {
            triggerQuestion()
        }
    }

    private func triggerQuestion() {
        showQuestion = true
        showResult = false
        selectedAnswer = nil
        ballLaunched = false // Pause ball
    }

    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer
        showResult = true
        questionsAnswered += 1

        let isCorrect = answer == currentQuestion?.question.correctAnswer

        if isCorrect {
            HapticsManager.shared.correctAnswer()
            questionsCorrect += 1
            score += 500 // Big bonus!
        } else {
            HapticsManager.shared.incorrectAnswer()
            ballsRemaining -= 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showQuestion = false

            if ballsRemaining <= 0 {
                endGame()
                return
            }

            // Resume play - need to relaunch ball
            if engine.hasMoreQuestions {
                currentQuestion = engine.nextQuestion()
            }
        }
    }

    private func loseBall() {
        ballLaunched = false
        ballsRemaining -= 1
        HapticsManager.shared.incorrectAnswer()

        if ballsRemaining <= 0 {
            endGame()
        }
    }

    private func endGame() {
        gameEnded = true
        HapticsManager.shared.gameTransition()
    }

    private func resetGame() {
        gameEnded = false
        showQuestion = false
        ballLaunched = false
        ballsRemaining = 3
        score = 0
        bumperHits = 0
        questionsAnswered = 0
        questionsCorrect = 0
        launchPower = 0
        hitEffects.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Pinball Bumper Model

struct PinballBumper: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let color: Color
    var isLit: Bool
}

// MARK: - Hit Effect Model

struct HitEffect: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let createdAt: Date
}

// MARK: - Pinball Table View

struct PinballTableView: View {
    var body: some View {
        ZStack {
            // Base color
            LinearGradient(
                colors: [Color(hex: "#1a1a2e"), Color(hex: "#2d1b3d")],
                startPoint: .top,
                endPoint: .bottom
            )

            // Side rails
            HStack {
                Rectangle()
                    .fill(Color(hex: "#4a4a6a"))
                    .frame(width: 20)
                Spacer()
                Rectangle()
                    .fill(Color(hex: "#4a4a6a"))
                    .frame(width: 20)
            }

            // Decorative lights
            VStack {
                HStack(spacing: 30) {
                    ForEach(0..<6, id: \.self) { _ in
                        Circle()
                            .fill(DesignSystem.Colors.orange.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 130)
                Spacer()
            }
        }
    }
}

// MARK: - Pinball Bumper View

struct PinballBumperView: View {
    let bumper: PinballBumper

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    bumper.isLit ? DesignSystem.Colors.orange : bumper.color,
                    lineWidth: 4
                )
                .frame(width: bumper.radius * 2 + 10, height: bumper.radius * 2 + 10)

            // Main bumper
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            bumper.isLit ? DesignSystem.Colors.orange : bumper.color,
                            bumper.isLit ? DesignSystem.Colors.red : bumper.color.opacity(0.7)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: bumper.radius
                    )
                )
                .frame(width: bumper.radius * 2, height: bumper.radius * 2)
                .shadow(color: bumper.isLit ? DesignSystem.Colors.orange : bumper.color, radius: bumper.isLit ? 15 : 5)
        }
        .position(x: bumper.x, y: bumper.y)
    }
}

// MARK: - Flipper View

struct FlipperView: View {
    let isLeft: Bool
    let isUp: Bool

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [DesignSystem.Colors.orange, DesignSystem.Colors.red],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 80, height: 18)
            .rotationEffect(.degrees(isUp ? (isLeft ? -30 : 30) : (isLeft ? 20 : -20)))
            .offset(x: isLeft ? 20 : -20)
            .shadow(color: DesignSystem.Colors.orange, radius: isUp ? 10 : 3)
            .animation(.spring(response: 0.1, dampingFraction: 0.5), value: isUp)
    }
}

// MARK: - Launch Lane View

struct LaunchLaneView: View {
    let power: CGFloat
    let isCharging: Bool

    var body: some View {
        ZStack {
            // Lane
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#3a3a5a"))
                .frame(width: 30, height: 300)

            // Power meter
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.cyan, DesignSystem.Colors.orange],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 20, height: power * 2.5)
            }
            .frame(height: 280)

            // Plunger
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "#8a8aaa"))
                    .frame(width: 24, height: 40)
                    .offset(y: isCharging ? power * 0.5 : 0)
            }
            .frame(height: 300)
        }
    }
}

// MARK: - Hit Effect View

struct HitEffectView: View {
    let effect: HitEffect

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .stroke(DesignSystem.Colors.orange, lineWidth: 4)
            .frame(width: 60, height: 60)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(x: effect.x, y: effect.y)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 2.0
                    opacity = 0
                }
            }
    }
}
