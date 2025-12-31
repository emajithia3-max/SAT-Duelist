import SwiftUI

// MARK: - Asteroid Dodge Game
// Tilt/swipe to dodge asteroids, answer questions to get shields and power-ups!

struct AsteroidDodgeGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var shipX: CGFloat = 200
    @State private var asteroids: [AsteroidObject] = []
    @State private var powerUps: [PowerUp] = []
    @State private var currentQuestion: LoadedQuestion?
    @State private var score: Int = 0
    @State private var shields: Int = 3
    @State private var gameEnded = false
    @State private var showQuestion = false
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var distance: Int = 0
    @State private var speedMultiplier: Double = 1.0
    @State private var isInvincible = false

    let shipWidth: CGFloat = 50

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    let asteroidSpawner = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    let questionTimer = Timer.publish(every: 8.0, on: .main, in: .common).autoconnect()
    let distanceTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true, motionBlur: speedMultiplier > 1.5) {
                ZStack {
                    // Space background with stars
                    SpaceBackgroundView(speed: speedMultiplier)

                    // Asteroids
                    ForEach(asteroids) { asteroid in
                        AsteroidView(asteroid: asteroid)
                    }

                    // Power-ups
                    ForEach(powerUps) { powerUp in
                        PowerUpView(powerUp: powerUp)
                    }

                    // Ship
                    ShipView(isInvincible: isInvincible)
                        .position(x: shipX, y: geometry.size.height - 150)

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            shieldsDisplay
                            Spacer()
                            distanceDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)

                        Spacer()
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
                    DragGesture()
                        .onChanged { value in
                            guard !showQuestion && !gameEnded else { return }
                            shipX = min(max(shipWidth/2, value.location.x), geometry.size.width - shipWidth/2)
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
        .onReceive(asteroidSpawner) { _ in
            guard !gameEnded && !showQuestion else { return }
            spawnAsteroid()
        }
        .onReceive(questionTimer) { _ in
            guard !gameEnded && !showQuestion else { return }
            triggerQuestion()
        }
        .onReceive(distanceTimer) { _ in
            guard !gameEnded && !showQuestion else { return }
            distance += Int(10 * speedMultiplier)
            // Increase difficulty
            if distance % 1000 == 0 {
                speedMultiplier = min(2.5, speedMultiplier + 0.1)
            }
        }
    }

    // MARK: - Shields Display

    private var shieldsDisplay: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < shields ? "shield.fill" : "shield")
                    .foregroundColor(index < shields ? DesignSystem.Colors.cyan : DesignSystem.Colors.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Distance Display

    private var distanceDisplay: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up")
                .foregroundColor(DesignSystem.Colors.orange)
            Text("\(distance)m")
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
        VStack(spacing: 16) {
            Text("INCOMING TRANSMISSION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(DesignSystem.Colors.cyan)

            Text(question.question.question)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, 16)

            // Answer buttons
            VStack(spacing: 10) {
                ForEach(question.question.allAnswers, id: \.self) { answer in
                    Button {
                        selectAnswer(answer)
                    } label: {
                        Text(answer)
                            .font(DesignSystem.Typography.body())
                            .foregroundColor(answerTextColor(answer, question: question))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(answerBackgroundColor(answer, question: question))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(answerBorderColor(answer, question: question), lineWidth: 2)
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

    private func answerTextColor(_ answer: String, question: LoadedQuestion) -> Color {
        if showResult {
            if answer == question.question.correctAnswer {
                return .white
            } else if answer == selectedAnswer {
                return .white
            }
        }
        return DesignSystem.Colors.textPrimary
    }

    private func answerBackgroundColor(_ answer: String, question: LoadedQuestion) -> Color {
        if showResult {
            if answer == question.question.correctAnswer {
                return DesignSystem.Colors.cyan.opacity(0.3)
            } else if answer == selectedAnswer {
                return DesignSystem.Colors.red.opacity(0.3)
            }
        }
        return DesignSystem.Colors.cardBackground
    }

    private func answerBorderColor(_ answer: String, question: LoadedQuestion) -> Color {
        if showResult {
            if answer == question.question.correctAnswer {
                return DesignSystem.Colors.cyan
            } else if answer == selectedAnswer {
                return DesignSystem.Colors.red
            }
        }
        return DesignSystem.Colors.cardBorder
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 24) {
            Text("GAME OVER")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.red)

            VStack(spacing: 16) {
                StatRow(icon: "arrow.up", label: "Distance", value: "\(distance)m", color: DesignSystem.Colors.orange)
                StatRow(icon: "checkmark.circle.fill", label: "Correct", value: "\(engine.correctAnswers)", color: DesignSystem.Colors.cyan)
                StatRow(icon: "bolt.fill", label: "Max Speed", value: "\(String(format: "%.1f", speedMultiplier))x", color: DesignSystem.Colors.primary)
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

        shipX = UIScreen.main.bounds.width / 2
    }

    private func spawnAsteroid() {
        let screenWidth = UIScreen.main.bounds.width
        let asteroid = AsteroidObject(
            id: UUID(),
            x: CGFloat.random(in: 40...(screenWidth - 40)),
            y: -50,
            size: CGFloat.random(in: 30...60),
            speed: CGFloat.random(in: 4...8) * CGFloat(speedMultiplier),
            rotation: Double.random(in: 0...360)
        )
        asteroids.append(asteroid)
    }

    private func updateGame() {
        let screenHeight = UIScreen.main.bounds.height

        // Move asteroids
        for i in asteroids.indices.reversed() {
            asteroids[i].y += asteroids[i].speed
            asteroids[i].rotation += 2

            // Remove off-screen asteroids
            if asteroids[i].y > screenHeight + 50 {
                asteroids.remove(at: i)
                continue
            }

            // Check collision with ship
            if !isInvincible && !showQuestion {
                let dx = asteroids[i].x - shipX
                let dy = asteroids[i].y - (screenHeight - 150)
                let distance = sqrt(dx*dx + dy*dy)

                if distance < (asteroids[i].size/2 + shipWidth/2 - 10) {
                    hitByAsteroid(at: i)
                }
            }
        }

        // Move power-ups
        for i in powerUps.indices.reversed() {
            powerUps[i].y += 3

            if powerUps[i].y > screenHeight + 50 {
                powerUps.remove(at: i)
                continue
            }

            // Check collection
            let dx = powerUps[i].x - shipX
            let dy = powerUps[i].y - (screenHeight - 150)
            let distance = sqrt(dx*dx + dy*dy)

            if distance < 40 {
                collectPowerUp(at: i)
            }
        }
    }

    private func hitByAsteroid(at index: Int) {
        asteroids.remove(at: index)
        shields -= 1
        HapticsManager.shared.incorrectAnswer()

        if shields <= 0 {
            endGame()
        } else {
            // Brief invincibility
            isInvincible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isInvincible = false
            }
        }
    }

    private func collectPowerUp(at index: Int) {
        let powerUp = powerUps[index]
        powerUps.remove(at: index)

        HapticsManager.shared.correctAnswer()

        switch powerUp.type {
        case .shield:
            shields = min(3, shields + 1)
        case .slowTime:
            speedMultiplier = max(1.0, speedMultiplier - 0.3)
        case .clearScreen:
            asteroids.removeAll()
        }
    }

    private func triggerQuestion() {
        showQuestion = true
        showResult = false
        selectedAnswer = nil
    }

    private func selectAnswer(_ answer: String) {
        guard !showResult else { return }

        selectedAnswer = answer
        showResult = true

        let isCorrect = answer == currentQuestion?.question.correctAnswer

        if isCorrect {
            HapticsManager.shared.correctAnswer()
            score += 100
            // Spawn power-up
            spawnPowerUp()
        } else {
            HapticsManager.shared.incorrectAnswer()
        }

        _ = engine.submitAnswer(answer)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showQuestion = false
            advanceQuestion()
        }
    }

    private func spawnPowerUp() {
        let screenWidth = UIScreen.main.bounds.width
        let types: [PowerUpType] = [.shield, .slowTime, .clearScreen]
        let powerUp = PowerUp(
            id: UUID(),
            x: CGFloat.random(in: 50...(screenWidth - 50)),
            y: -30,
            type: types.randomElement() ?? .shield
        )
        powerUps.append(powerUp)
    }

    private func advanceQuestion() {
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
        showQuestion = false
        score = 0
        shields = 3
        distance = 0
        speedMultiplier = 1.0
        asteroids.removeAll()
        powerUps.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Asteroid Object

struct AsteroidObject: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var speed: CGFloat
    var rotation: Double
}

// MARK: - Power Up

struct PowerUp: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let type: PowerUpType
}

enum PowerUpType {
    case shield, slowTime, clearScreen

    var icon: String {
        switch self {
        case .shield: return "shield.fill"
        case .slowTime: return "clock.fill"
        case .clearScreen: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .shield: return DesignSystem.Colors.cyan
        case .slowTime: return DesignSystem.Colors.primary
        case .clearScreen: return DesignSystem.Colors.orange
        }
    }
}

// MARK: - Asteroid View

struct AsteroidView: View {
    let asteroid: AsteroidObject

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(DesignSystem.Colors.red.opacity(0.3))
                .frame(width: asteroid.size + 10, height: asteroid.size + 10)
                .blur(radius: 5)

            // Asteroid body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#8B7355"), Color(hex: "#5D4E37")],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: asteroid.size
                    )
                )
                .frame(width: asteroid.size, height: asteroid.size)
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#4A3C2A"), lineWidth: 2)
                )
        }
        .rotationEffect(.degrees(asteroid.rotation))
        .position(x: asteroid.x, y: asteroid.y)
    }
}

// MARK: - Power Up View

struct PowerUpView: View {
    let powerUp: PowerUp

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(powerUp.type.color.opacity(0.3))
                .frame(width: 50, height: 50)
                .scaleEffect(pulse ? 1.3 : 1.0)

            Circle()
                .fill(powerUp.type.color)
                .frame(width: 35, height: 35)

            Image(systemName: powerUp.type.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .position(x: powerUp.x, y: powerUp.y)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Ship View

struct ShipView: View {
    let isInvincible: Bool

    @State private var glow = false

    var body: some View {
        ZStack {
            // Engine glow
            Ellipse()
                .fill(DesignSystem.Colors.cyan.opacity(0.4))
                .frame(width: 30, height: 50)
                .blur(radius: 10)
                .offset(y: 30)

            // Ship body
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(isInvincible ? DesignSystem.Colors.cyan : DesignSystem.Colors.primary)
                .shadow(color: DesignSystem.Colors.primary, radius: glow ? 15 : 5)

            // Shield effect
            if isInvincible {
                Circle()
                    .stroke(DesignSystem.Colors.cyan, lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .opacity(glow ? 0.8 : 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

// MARK: - Space Background View

struct SpaceBackgroundView: View {
    let speed: Double
    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0a0a15"), Color(hex: "#15152a")],
                startPoint: .top,
                endPoint: .bottom
            )

            // Moving stars
            GeometryReader { geometry in
                ForEach(0..<80, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(Double.random(in: 0.3...0.8)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat(i * 5 % Int(geometry.size.width)),
                            y: (CGFloat(i * 13 % Int(geometry.size.height)) + offset).truncatingRemainder(dividingBy: geometry.size.height)
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2 / speed).repeatForever(autoreverses: false)) {
                offset = UIScreen.main.bounds.height
            }
        }
    }
}
