import SwiftUI

// MARK: - Space Shooter Game
// Classic space shooter - blast aliens! Periodic questions pause the game.

struct SpaceShooterGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var shipX: CGFloat = 200
    @State private var bullets: [Bullet] = []
    @State private var aliens: [Alien] = []
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var gameEnded = false
    @State private var aliensDestroyed: Int = 0
    @State private var explosions: [SpaceShooterExplosion] = []

    // Question state
    @State private var showQuestion = false
    @State private var currentQuestion: LoadedQuestion?
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var questionsAnswered: Int = 0
    @State private var questionsCorrect: Int = 0

    let questionInterval: Int = 6 // Question every 6 aliens destroyed

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    let alienSpawner = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    let autoFire = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Space background
                    SpaceShooterBackgroundView()

                    // Aliens
                    ForEach(aliens) { alien in
                        AlienView(alien: alien)
                    }

                    // Bullets
                    ForEach(bullets) { bullet in
                        BulletView(bullet: bullet)
                    }

                    // Explosions
                    ForEach(explosions) { explosion in
                        SpaceShooterExplosionView(explosion: explosion)
                    }

                    // Player ship
                    if !showQuestion {
                        SpaceShooterShipView()
                            .position(x: shipX, y: geometry.size.height - 120)
                    }

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            livesDisplay
                            Spacer()
                            killsDisplay
                            Spacer()
                            scoreDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)

                        Spacer()

                        if !showQuestion && !gameEnded {
                            Text("DRAG TO MOVE - AUTO FIRE!")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.cyan.opacity(0.8))
                                .padding(.bottom, 40)
                        }
                    }

                    // Drag area
                    if !showQuestion && !gameEnded {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        shipX = min(max(40, value.location.x), geometry.size.width - 40)
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
        .onReceive(alienSpawner) { _ in
            guard !gameEnded && !showQuestion else { return }
            spawnAlien()
        }
        .onReceive(autoFire) { _ in
            guard !gameEnded && !showQuestion else { return }
            fireBullet()
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

    // MARK: - Kills Display

    private var killsDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "target")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.orange)
            Text("\(aliensDestroyed)")
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
            Text("POWER-UP CHALLENGE!")
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
                StatRow(icon: "target", label: "Aliens Destroyed", value: "\(aliensDestroyed)", color: DesignSystem.Colors.cyan)
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
        shipX = UIScreen.main.bounds.width / 2
    }

    private func spawnAlien() {
        let screenWidth = UIScreen.main.bounds.width

        let alien = Alien(
            id: UUID(),
            x: CGFloat.random(in: 50...(screenWidth - 50)),
            y: -50,
            speed: CGFloat.random(in: 2...4),
            size: CGFloat.random(in: 35...50)
        )
        aliens.append(alien)
    }

    private func fireBullet() {
        let bullet = Bullet(
            id: UUID(),
            x: shipX,
            y: UIScreen.main.bounds.height - 150
        )
        bullets.append(bullet)
        HapticsManager.shared.selectionChanged()
    }

    private func updateGame() {
        let screenHeight = UIScreen.main.bounds.height

        // Move bullets
        for i in bullets.indices.reversed() {
            bullets[i].y -= 10

            if bullets[i].y < -20 {
                bullets.remove(at: i)
            }
        }

        // Move aliens and check collisions
        for i in aliens.indices.reversed() {
            aliens[i].y += aliens[i].speed

            // Check bullet collisions
            for j in bullets.indices.reversed() {
                let dx = aliens[i].x - bullets[j].x
                let dy = aliens[i].y - bullets[j].y
                let distance = sqrt(dx*dx + dy*dy)

                if distance < aliens[i].size / 2 + 5 {
                    // Hit!
                    let explosion = SpaceShooterExplosion(id: UUID(), x: aliens[i].x, y: aliens[i].y, createdAt: Date())
                    explosions.append(explosion)

                    aliens.remove(at: i)
                    bullets.remove(at: j)
                    HapticsManager.shared.correctAnswer()

                    aliensDestroyed += 1
                    score += 50

                    // Trigger question periodically
                    if aliensDestroyed % questionInterval == 0 {
                        triggerQuestion()
                    }
                    break
                }
            }

            // Check if alien reached bottom
            if i < aliens.count && aliens[i].y > screenHeight - 100 {
                aliens.remove(at: i)
                lives -= 1
                HapticsManager.shared.incorrectAnswer()

                if lives <= 0 {
                    endGame()
                }
            }
        }

        // Clean up explosions
        explosions.removeAll { Date().timeIntervalSince($0.createdAt) > 0.4 }
    }

    private func triggerQuestion() {
        showQuestion = true
        showResult = false
        selectedAnswer = nil
        aliens.removeAll()
        bullets.removeAll()
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
        aliensDestroyed = 0
        questionsAnswered = 0
        questionsCorrect = 0
        bullets.removeAll()
        aliens.removeAll()
        explosions.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Models

struct Bullet: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
}

struct Alien: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var speed: CGFloat
    var size: CGFloat
}

struct SpaceShooterExplosion: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let createdAt: Date
}

// MARK: - Views

struct SpaceShooterShipView: View {
    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(DesignSystem.Colors.cyan.opacity(0.3))
                .frame(width: 60, height: 60)
                .blur(radius: 10)

            // Ship body
            Path { path in
                path.move(to: CGPoint(x: 0, y: -20))
                path.addLine(to: CGPoint(x: -15, y: 20))
                path.addLine(to: CGPoint(x: 15, y: 20))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [DesignSystem.Colors.cyan, DesignSystem.Colors.primary],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 30, height: 40)

            // Cockpit
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 8, height: 8)
                .offset(y: -5)
        }
    }
}

struct BulletView: View {
    let bullet: Bullet

    var body: some View {
        Capsule()
            .fill(DesignSystem.Colors.orange)
            .frame(width: 4, height: 15)
            .shadow(color: DesignSystem.Colors.orange, radius: 5)
            .position(x: bullet.x, y: bullet.y)
    }
}

struct AlienView: View {
    let alien: Alien

    var body: some View {
        ZStack {
            // Alien body
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#51CF66"), Color(hex: "#2F9E44")],
                        center: .center,
                        startRadius: 0,
                        endRadius: alien.size / 2
                    )
                )
                .frame(width: alien.size, height: alien.size * 0.7)

            // Eyes
            HStack(spacing: 8) {
                Circle()
                    .fill(.black)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(.black)
                    .frame(width: 8, height: 8)
            }
            .offset(y: -5)
        }
        .position(x: alien.x, y: alien.y)
    }
}

struct SpaceShooterExplosionView: View {
    let explosion: SpaceShooterExplosion

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(DesignSystem.Colors.orange)
                    .frame(width: 8, height: 8)
                    .offset(
                        x: cos(CGFloat(i) * .pi / 4) * 25 * scale,
                        y: sin(CGFloat(i) * .pi / 4) * 25 * scale
                    )
            }
        }
        .opacity(opacity)
        .position(x: explosion.x, y: explosion.y)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                scale = 2.5
                opacity = 0
            }
        }
    }
}

struct SpaceShooterBackgroundView: View {
    var body: some View {
        ZStack {
            // Dark space gradient
            LinearGradient(
                colors: [Color(hex: "#0a0a15"), Color(hex: "#1a0a25"), Color(hex: "#0a0a15")],
                startPoint: .top,
                endPoint: .bottom
            )

            // Stars
            GeometryReader { geometry in
                ForEach(0..<60, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(Double.random(in: 0.3...0.9)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat(i * 7 % Int(geometry.size.width)),
                            y: CGFloat(i * 13 % Int(geometry.size.height))
                        )
                }
            }
        }
    }
}
