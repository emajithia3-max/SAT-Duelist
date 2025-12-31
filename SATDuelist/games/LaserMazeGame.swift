import SwiftUI

// MARK: - Laser Maze Game
// Navigate through a laser maze - answer questions to open gates!

struct LaserMazeGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var playerPosition: CGPoint = CGPoint(x: 60, y: 400)
    @State private var targetPosition: CGPoint = CGPoint(x: 60, y: 400)
    @State private var lasers: [LaserBeam] = []
    @State private var gates: [LaserGate] = []
    @State private var currentQuestion: LoadedQuestion?
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var level: Int = 1
    @State private var gameEnded = false
    @State private var showQuestion = false
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var activeGate: LaserGate?
    @State private var isInvincible = false
    @State private var reachedEnd = false

    let playerRadius: CGFloat = 20
    let moveSpeed: CGFloat = 3

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Tech background
                    TechBackgroundView()

                    // Lasers
                    ForEach(lasers) { laser in
                        LaserView(laser: laser)
                    }

                    // Gates
                    ForEach(gates) { gate in
                        GateBlockView(gate: gate)
                    }

                    // Exit zone
                    ExitZoneView()
                        .position(x: geometry.size.width - 50, y: geometry.size.height / 2)

                    // Player
                    PlayerOrbView(isInvincible: isInvincible)
                        .position(playerPosition)

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            livesDisplay
                            Spacer()
                            levelDisplay
                            Spacer()
                            scoreDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)

                        Spacer()

                        // Instructions
                        if !showQuestion && !gameEnded {
                            Text("DRAG TO MOVE - REACH THE EXIT!")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.cyan)
                                .padding(.bottom, 20)
                        }
                    }

                    // Question overlay
                    if showQuestion, let question = currentQuestion {
                        questionOverlay(question)
                    }

                    // Level complete
                    if reachedEnd && !gameEnded {
                        levelCompleteOverlay
                    }

                    // Game over
                    if gameEnded {
                        gameOverOverlay
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard !showQuestion && !gameEnded && !reachedEnd else { return }
                            targetPosition = value.location
                        }
                )
            }
        }
        .ignoresSafeArea()
        .task {
            await startGame()
        }
        .onReceive(gameLoop) { _ in
            guard !gameEnded && !showQuestion && !reachedEnd else { return }
            updateGame()
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

    // MARK: - Level Display

    private var levelDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundColor(DesignSystem.Colors.primary)
            Text("Level \(level)")
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
        VStack(spacing: 16) {
            Text("UNLOCK THE GATE!")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(DesignSystem.Colors.cyan)

            Text(question.question.question)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                ForEach(question.question.allAnswers, id: \.self) { answer in
                    Button {
                        selectAnswer(answer)
                    } label: {
                        Text(answer)
                            .font(DesignSystem.Typography.body())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
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
                .fill(DesignSystem.Colors.primaryBackground.opacity(0.95))
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

    // MARK: - Level Complete Overlay

    private var levelCompleteOverlay: some View {
        VStack(spacing: 24) {
            Text("LEVEL \(level) COMPLETE!")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.cyan)

            Text("+\(level * 100) points")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.orange)

            PrimaryButton(title: "Next Level") {
                nextLevel()
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignSystem.Colors.primaryBackground.opacity(0.95))
        )
        .padding(20)
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 24) {
            Text("GAME OVER")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.red)

            VStack(spacing: 16) {
                StatRow(icon: "square.stack.3d.up.fill", label: "Level", value: "\(level)", color: DesignSystem.Colors.primary)
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "checkmark.circle.fill", label: "Correct", value: "\(engine.correctAnswers)", color: DesignSystem.Colors.cyan)
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

        setupLevel()
    }

    private func setupLevel() {
        lasers.removeAll()
        gates.removeAll()
        playerPosition = CGPoint(x: 60, y: UIScreen.main.bounds.height / 2)
        targetPosition = playerPosition
        reachedEnd = false

        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        // Add lasers based on level
        let laserCount = min(level + 2, 8)

        for i in 0..<laserCount {
            let isHorizontal = Bool.random()
            let laser = LaserBeam(
                id: UUID(),
                x: isHorizontal ? screenWidth / 2 : CGFloat.random(in: 100...(screenWidth - 100)),
                y: isHorizontal ? CGFloat.random(in: 200...(screenHeight - 200)) : screenHeight / 2,
                isHorizontal: isHorizontal,
                length: isHorizontal ? screenWidth - 100 : screenHeight - 300,
                oscillates: level > 2,
                phase: CGFloat(i) * 0.5
            )
            lasers.append(laser)
        }

        // Add gate
        let gate = LaserGate(
            id: UUID(),
            x: screenWidth * 0.6,
            y: screenHeight / 2,
            width: 20,
            height: 100,
            isOpen: false
        )
        gates.append(gate)
    }

    private func updateGame() {
        // Move player toward target
        let dx = targetPosition.x - playerPosition.x
        let dy = targetPosition.y - playerPosition.y
        let distance = sqrt(dx*dx + dy*dy)

        if distance > moveSpeed {
            playerPosition.x += (dx / distance) * moveSpeed
            playerPosition.y += (dy / distance) * moveSpeed
        }

        // Keep in bounds
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        playerPosition.x = max(playerRadius, min(screenWidth - playerRadius, playerPosition.x))
        playerPosition.y = max(playerRadius + 100, min(screenHeight - playerRadius - 50, playerPosition.y))

        // Update oscillating lasers
        for i in lasers.indices {
            if lasers[i].oscillates {
                lasers[i].phase += 0.03
            }
        }

        // Check laser collisions
        if !isInvincible {
            for laser in lasers {
                if checkLaserCollision(laser) {
                    hitByLaser()
                    return
                }
            }
        }

        // Check gate collision
        for gate in gates {
            if !gate.isOpen && checkGateCollision(gate) {
                activeGate = gate
                triggerQuestion()
                return
            }
        }

        // Check if reached exit
        let exitX = screenWidth - 50
        let exitY = screenHeight / 2

        if sqrt(pow(playerPosition.x - exitX, 2) + pow(playerPosition.y - exitY, 2)) < 50 {
            reachExit()
        }
    }

    private func checkLaserCollision(_ laser: LaserBeam) -> Bool {
        let offset = laser.oscillates ? sin(laser.phase) * 50 : 0

        if laser.isHorizontal {
            let laserY = laser.y + offset
            return abs(playerPosition.y - laserY) < playerRadius + 3 &&
                   playerPosition.x > laser.x - laser.length/2 &&
                   playerPosition.x < laser.x + laser.length/2
        } else {
            let laserX = laser.x + offset
            return abs(playerPosition.x - laserX) < playerRadius + 3 &&
                   playerPosition.y > laser.y - laser.length/2 &&
                   playerPosition.y < laser.y + laser.length/2
        }
    }

    private func checkGateCollision(_ gate: LaserGate) -> Bool {
        return playerPosition.x > gate.x - gate.width/2 - playerRadius &&
               playerPosition.x < gate.x + gate.width/2 + playerRadius &&
               playerPosition.y > gate.y - gate.height/2 - playerRadius &&
               playerPosition.y < gate.y + gate.height/2 + playerRadius
    }

    private func hitByLaser() {
        lives -= 1
        HapticsManager.shared.incorrectAnswer()

        if lives <= 0 {
            endGame()
        } else {
            // Reset position and brief invincibility
            playerPosition = CGPoint(x: 60, y: UIScreen.main.bounds.height / 2)
            targetPosition = playerPosition
            isInvincible = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isInvincible = false
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

        let isCorrect = answer == currentQuestion?.question.correctAnswer

        if isCorrect {
            HapticsManager.shared.correctAnswer()
            score += 50

            // Open the gate
            if let gateIndex = gates.firstIndex(where: { $0.id == activeGate?.id }) {
                gates[gateIndex].isOpen = true
            }
        } else {
            HapticsManager.shared.incorrectAnswer()
            // Push player back
            playerPosition = CGPoint(x: 60, y: UIScreen.main.bounds.height / 2)
            targetPosition = playerPosition
        }

        _ = engine.submitAnswer(answer)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showQuestion = false
            activeGate = nil
            advanceQuestion()
        }
    }

    private func advanceQuestion() {
        if engine.hasMoreQuestions {
            currentQuestion = engine.nextQuestion()
        }
    }

    private func reachExit() {
        reachedEnd = true
        HapticsManager.shared.correctAnswer()
        score += level * 100
    }

    private func nextLevel() {
        level += 1
        reachedEnd = false
        setupLevel()
    }

    private func endGame() {
        gameEnded = true
        HapticsManager.shared.gameTransition()
    }

    private func resetGame() {
        gameEnded = false
        lives = 3
        score = 0
        level = 1
        lasers.removeAll()
        gates.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Laser Beam Model

struct LaserBeam: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let isHorizontal: Bool
    let length: CGFloat
    let oscillates: Bool
    var phase: CGFloat
}

// MARK: - Laser Gate Model

struct LaserGate: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    var isOpen: Bool
}

// MARK: - Tech Background View

struct TechBackgroundView: View {
    var body: some View {
        ZStack {
            Color(hex: "#0a0a15")

            // Grid
            GeometryReader { geometry in
                Path { path in
                    let spacing: CGFloat = 50
                    for x in stride(from: 0, to: geometry.size.width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    for y in stride(from: 0, to: geometry.size.height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(DesignSystem.Colors.primary.opacity(0.1), lineWidth: 1)
            }
        }
    }
}

// MARK: - Laser View

struct LaserView: View {
    let laser: LaserBeam

    @State private var pulse = false

    var body: some View {
        let offset = laser.oscillates ? sin(laser.phase) * 50 : 0

        ZStack {
            // Glow
            Rectangle()
                .fill(DesignSystem.Colors.red.opacity(0.3))
                .frame(
                    width: laser.isHorizontal ? laser.length : 12,
                    height: laser.isHorizontal ? 12 : laser.length
                )
                .blur(radius: 8)

            // Core
            Rectangle()
                .fill(DesignSystem.Colors.red)
                .frame(
                    width: laser.isHorizontal ? laser.length : 4,
                    height: laser.isHorizontal ? 4 : laser.length
                )
                .shadow(color: DesignSystem.Colors.red, radius: pulse ? 10 : 5)
        }
        .position(
            x: laser.x + (laser.isHorizontal ? 0 : offset),
            y: laser.y + (laser.isHorizontal ? offset : 0)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Gate Block View

struct GateBlockView: View {
    let gate: LaserGate

    var body: some View {
        ZStack {
            if !gate.isOpen {
                // Barrier
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignSystem.Colors.orange)
                    .frame(width: gate.width, height: gate.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.white.opacity(0.5), lineWidth: 2)
                    )
                    .shadow(color: DesignSystem.Colors.orange, radius: 8)

                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            } else {
                // Open gate
                RoundedRectangle(cornerRadius: 4)
                    .stroke(DesignSystem.Colors.cyan, lineWidth: 2)
                    .frame(width: gate.width, height: gate.height)
                    .opacity(0.5)
            }
        }
        .position(x: gate.x, y: gate.y)
    }
}

// MARK: - Exit Zone View

struct ExitZoneView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.cyan.opacity(0.2))
                .frame(width: 80, height: 80)
                .scaleEffect(pulse ? 1.2 : 1.0)

            Circle()
                .stroke(DesignSystem.Colors.cyan, lineWidth: 3)
                .frame(width: 60, height: 60)

            Image(systemName: "flag.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(DesignSystem.Colors.cyan)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Player Orb View

struct PlayerOrbView: View {
    let isInvincible: Bool

    @State private var glow = false

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(DesignSystem.Colors.cyan.opacity(0.3))
                .frame(width: 50, height: 50)
                .blur(radius: 8)
                .opacity(glow ? 1 : 0.5)

            // Core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, DesignSystem.Colors.cyan],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 30, height: 30)
                .shadow(color: DesignSystem.Colors.cyan, radius: isInvincible ? 15 : 5)

            // Invincibility shield
            if isInvincible {
                Circle()
                    .stroke(DesignSystem.Colors.cyan, lineWidth: 2)
                    .frame(width: 45, height: 45)
                    .opacity(glow ? 1 : 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
