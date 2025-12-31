import SwiftUI

// MARK: - Tower Climb Game
// Platformer-style game - climb the tower by answering questions correctly!
// Each correct answer jumps you up a floor. Wrong answers make you fall!

struct TowerClimbGame: View {
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

    // Tower Climb specific state
    @State private var currentFloor: Int = 1
    @State private var maxFloor: Int = 1
    @State private var targetFloor: Int = 20
    @State private var playerY: CGFloat = 0
    @State private var isJumping = false
    @State private var isFalling = false
    @State private var platforms: [Platform] = []
    @State private var collectibles: [Collectible] = []
    @State private var score: Int = 0
    @State private var floorsClimbed: Int = 0
    @State private var combo: Int = 0

    // Answer options for MCQ
    @State private var answerOptions: [String] = []

    // Animation constants
    private let platformHeight: CGFloat = 60
    private let jumpDuration: Double = 0.5
    private let fallDuration: Double = 0.4

    var body: some View {
        CinematicContainer(
            vignette: true,
            bloom: true,
            motionBlur: isJumping || isFalling,
            grain: false,
            motionBlurIntensity: 0.4
        ) {
            GeometryReader { geometry in
                ZStack {
                    // Tower background
                    TowerBackground(currentFloor: currentFloor, targetFloor: targetFloor)

                    // Platforms
                    ForEach(platforms) { platform in
                        PlatformView(platform: platform, currentFloor: currentFloor)
                    }

                    // Collectibles
                    ForEach(collectibles) { collectible in
                        CollectibleView(collectible: collectible)
                    }

                    // Player character
                    PlayerCharacterView(
                        isJumping: isJumping,
                        isFalling: isFalling
                    )
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + playerY)

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            closeButton
                            Spacer()
                            floorIndicator
                            Spacer()
                            scoreIndicator
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // Progress bar
                        progressBar
                            .padding(.horizontal, 40)
                            .padding(.top, 8)

                        Spacer()

                        // Question panel
                        if let question = currentQuestion, !gameEnded {
                            climbQuestionView(question)
                        }
                    }

                    // Victory/Game Over overlay
                    if gameEnded {
                        gameEndOverlay
                    }
                }
            }
            .ignoresSafeArea()
        }
        .task {
            await startGame()
        }
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

    // MARK: - Floor Indicator

    private var floorIndicator: some View {
        VStack(spacing: 2) {
            Text("FLOOR")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textMuted)

            Text("\(currentFloor)")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Score Indicator

    private var scoreIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .foregroundColor(DesignSystem.Colors.orange)
            Text("\(score)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignSystem.Colors.elevated)

                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(currentFloor) / CGFloat(targetFloor))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentFloor)

                    // Goal flag
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.orange)
                        .position(x: geometry.size.width - 10, y: 6)
                }
            }
            .frame(height: 12)

            HStack {
                Text("Start")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                Spacer()
                Text("Floor \(targetFloor)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.orange)
            }
        }
    }

    // MARK: - Climb Question View

    private func climbQuestionView(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 12) {
            // Combo indicator
            if combo > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("\(combo)x Combo!")
                }
                .font(DesignSystem.Typography.caption())
                .foregroundColor(DesignSystem.Colors.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.orange.opacity(0.2))
                )
            }

            // Question
            Text(question.question.question)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 12)

            // Answer buttons
            if question.question.isMultipleChoice {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(answerOptions, id: \.self) { answer in
                        ClimbAnswerButton(
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
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(DesignSystem.Colors.cyan)
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

    // MARK: - Game End Overlay

    private var gameEndOverlay: some View {
        VStack(spacing: 24) {
            if currentFloor >= targetFloor {
                Text("SUMMIT REACHED!")
                    .font(DesignSystem.Typography.screenTitle())
                    .foregroundColor(DesignSystem.Colors.cyan)

                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.primary)
            } else {
                Text("CLIMB COMPLETE")
                    .font(DesignSystem.Typography.screenTitle())
                    .foregroundColor(DesignSystem.Colors.primary)

                Text("Reached Floor \(maxFloor)")
                    .font(DesignSystem.Typography.cardTitle())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            VStack(spacing: 12) {
                StatRow(icon: "arrow.up.circle.fill", label: "Highest Floor", value: "\(maxFloor)", color: DesignSystem.Colors.primary)
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "checkmark.circle.fill", label: "Correct", value: "\(engine.correctAnswers)", color: DesignSystem.Colors.cyan)
                StatRow(icon: "flame.fill", label: "Best Combo", value: "\(engine.maxStreak)x", color: DesignSystem.Colors.orange)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            PrimaryButton(title: "Climb Again") {
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

        // Generate initial platforms
        generatePlatforms()

        HapticsManager.shared.gameTransition()

        if let question = engine.startSession() {
            currentQuestion = question
            answerOptions = question.question.allAnswers

            withAnimation(DesignSystem.Animation.spring) {
                isCardPresented = true
            }
        }
    }

    private func generatePlatforms() {
        platforms = (0..<25).map { floor in
            Platform(
                id: UUID(),
                floor: floor,
                width: CGFloat.random(in: 80...140),
                xOffset: CGFloat.random(in: -60...60)
            )
        }
    }

    private func selectAnswer(_ answer: String) {
        guard !showResult, !isJumping, !isFalling else { return }

        HapticsManager.shared.answerTap()
        selectedAnswer = answer
        submitAnswer(answer)
    }

    private func submitSPRAnswer() {
        guard !showResult, !sprAnswer.isEmpty, !isJumping, !isFalling else { return }
        HapticsManager.shared.answerTap()
        submitAnswer(sprAnswer)
    }

    private func submitAnswer(_ answer: String) {
        let result = engine.submitAnswer(answer)
        answerResult = result

        if result.isCorrect {
            HapticsManager.shared.correctAnswer()
            combo += 1
            jumpUp()
        } else {
            HapticsManager.shared.incorrectAnswer()
            combo = 0
            fallDown()
        }

        showResult = true
    }

    private func jumpUp() {
        isJumping = true
        showGlow = true

        // Calculate score with combo bonus
        let baseScore = 100
        let comboBonus = (combo - 1) * 25
        score += baseScore + comboBonus

        withAnimation(.spring(response: jumpDuration, dampingFraction: 0.6)) {
            playerY = -100
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + jumpDuration) {
            currentFloor += 1
            maxFloor = max(maxFloor, currentFloor)
            floorsClimbed += 1

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                playerY = 0
                isJumping = false
                showGlow = false
            }

            // Check if reached summit
            if currentFloor >= targetFloor {
                endGame()
            } else {
                advanceToNext()
            }
        }
    }

    private func fallDown() {
        isFalling = true
        showError = true
        shakeTrigger += 1

        withAnimation(.easeIn(duration: fallDuration)) {
            playerY = 100
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + fallDuration) {
            currentFloor = max(1, currentFloor - 1)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                playerY = 0
                isFalling = false
                showError = false
            }

            advanceToNext()
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
        currentFloor = 1
        maxFloor = 1
        score = 0
        floorsClimbed = 0
        combo = 0
        playerY = 0
        isJumping = false
        isFalling = false
        gameEnded = false
        selectedAnswer = nil
        answerResult = nil
        showResult = false
        sprAnswer = ""

        generatePlatforms()

        Task {
            await startGame()
        }
    }
}

// MARK: - Supporting Types

struct Platform: Identifiable {
    let id: UUID
    let floor: Int
    let width: CGFloat
    let xOffset: CGFloat
}

struct Collectible: Identifiable {
    let id: UUID
    let floor: Int
    let type: CollectibleType
    let xOffset: CGFloat

    enum CollectibleType {
        case star
        case gem
        case coin
    }
}

// MARK: - Tower Background

struct TowerBackground: View {
    let currentFloor: Int
    let targetFloor: Int

    var body: some View {
        ZStack {
            // Sky gradient based on height
            LinearGradient(
                colors: skyColors,
                startPoint: .top,
                endPoint: .bottom
            )

            // Clouds (appear higher up)
            if currentFloor > 5 {
                CloudsView(density: min(1.0, Double(currentFloor - 5) / 10.0))
            }

            // Tower structure
            GeometryReader { geometry in
                ForEach(0..<10, id: \.self) { i in
                    Rectangle()
                        .fill(DesignSystem.Colors.cardBorder.opacity(0.3))
                        .frame(width: 2, height: geometry.size.height)
                        .position(x: CGFloat(i) * geometry.size.width / 9, y: geometry.size.height / 2)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var skyColors: [Color] {
        let progress = Double(currentFloor) / Double(targetFloor)
        if progress < 0.3 {
            return [Color(hex: "#1a1a2e"), Color(hex: "#16213e"), DesignSystem.Colors.primaryBackground]
        } else if progress < 0.6 {
            return [Color(hex: "#16213e"), Color(hex: "#0f3460"), Color(hex: "#1a1a2e")]
        } else if progress < 0.9 {
            return [Color(hex: "#0f3460"), Color(hex: "#533483"), Color(hex: "#16213e")]
        } else {
            return [Color(hex: "#e94560"), Color(hex: "#533483"), Color(hex: "#0f3460")]
        }
    }
}

// MARK: - Clouds View

struct CloudsView: View {
    let density: Double

    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<Int(density * 8), id: \.self) { i in
                Cloud()
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 100...geometry.size.height - 200)
                    )
                    .opacity(Double.random(in: 0.1...0.3))
            }
        }
    }
}

struct Cloud: View {
    var body: some View {
        HStack(spacing: -20) {
            Circle()
                .fill(.white)
                .frame(width: 40, height: 40)
            Circle()
                .fill(.white)
                .frame(width: 60, height: 60)
            Circle()
                .fill(.white)
                .frame(width: 45, height: 45)
        }
        .blur(radius: 10)
    }
}

// MARK: - Platform View

struct PlatformView: View {
    let platform: Platform
    let currentFloor: Int

    var body: some View {
        let isCurrentFloor = platform.floor == currentFloor
        let isVisible = abs(platform.floor - currentFloor) <= 3

        if isVisible {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isCurrentFloor ?
                        LinearGradient(
                            colors: [DesignSystem.Colors.primary, DesignSystem.Colors.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [DesignSystem.Colors.elevated, DesignSystem.Colors.cardBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: platform.width, height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isCurrentFloor ? DesignSystem.Colors.cyan : DesignSystem.Colors.cardBorder,
                                lineWidth: isCurrentFloor ? 2 : 1
                            )
                    )
                    .shadow(color: isCurrentFloor ? DesignSystem.Colors.primary.opacity(0.5) : .clear, radius: 10)
                    .position(
                        x: geometry.size.width / 2 + platform.xOffset,
                        y: geometry.size.height / 2 + CGFloat(currentFloor - platform.floor) * 80
                    )
                    .opacity(isVisible ? 1 : 0)
            }
        }
    }
}

// MARK: - Collectible View

struct CollectibleView: View {
    let collectible: Collectible
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(iconColor)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }

    private var iconName: String {
        switch collectible.type {
        case .star: return "star.fill"
        case .gem: return "diamond.fill"
        case .coin: return "circle.fill"
        }
    }

    private var iconColor: Color {
        switch collectible.type {
        case .star: return DesignSystem.Colors.orange
        case .gem: return DesignSystem.Colors.cyan
        case .coin: return Color(hex: "#FFD700")
        }
    }
}

// MARK: - Player Character View

struct PlayerCharacterView: View {
    let isJumping: Bool
    let isFalling: Bool

    @State private var bounce: CGFloat = 0

    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(DesignSystem.Colors.cyan.opacity(0.3))
                .frame(width: 60, height: 60)
                .blur(radius: 15)
                .scaleEffect(isJumping ? 1.5 : 1.0)

            // Character body
            ZStack {
                // Body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.cyan, DesignSystem.Colors.primary],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 40, height: 40)

                // Face
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                    }

                    if isJumping {
                        // Happy mouth
                        Capsule()
                            .fill(.white)
                            .frame(width: 12, height: 4)
                    } else if isFalling {
                        // Worried mouth
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                    } else {
                        // Neutral mouth
                        Capsule()
                            .fill(.white)
                            .frame(width: 10, height: 3)
                    }
                }
                .offset(y: 2)
            }
            .scaleEffect(isJumping ? 1.1 : (isFalling ? 0.9 : 1.0))
            .offset(y: bounce)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                bounce = -5
            }
        }
    }
}

// MARK: - Climb Answer Button

struct ClimbAnswerButton: View {
    let answer: String
    let isSelected: Bool
    let isCorrect: Bool?
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: buttonIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(iconColor)

                Text(answer)
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
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

    private var buttonIcon: String {
        if let correct = isCorrect {
            return correct ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        }
        return "circle"
    }

    private var iconColor: Color {
        if let correct = isCorrect {
            return correct ? DesignSystem.Colors.cyan : DesignSystem.Colors.red
        }
        return DesignSystem.Colors.textMuted
    }

    private var textColor: Color {
        if isCorrect != nil {
            return .white
        }
        return DesignSystem.Colors.textPrimary
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
