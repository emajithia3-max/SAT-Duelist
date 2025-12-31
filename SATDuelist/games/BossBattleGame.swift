import SwiftUI

// MARK: - Boss Battle Game
// RPG-style boss fight - correct answers deal damage, wrong answers hurt you!
// Defeat the boss before your HP runs out

struct BossBattleGame: View {
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

    // Boss Battle specific state
    @State private var playerHP: Int = 100
    @State private var playerMaxHP: Int = 100
    @State private var bossHP: Int = 500
    @State private var bossMaxHP: Int = 500
    @State private var bossName: String = "The Examinator"
    @State private var currentBossLevel: Int = 1
    @State private var totalDamageDealt: Int = 0
    @State private var streak: Int = 0
    @State private var showPlayerDamage = false
    @State private var showBossDamage = false
    @State private var lastDamage: Int = 0
    @State private var victory = false
    @State private var bossShake = false
    @State private var playerShake = false

    // Answer options for MCQ
    @State private var answerOptions: [String] = []

    // Boss attack timer
    let bossAttackTimer = Timer.publish(every: 8.0, on: .main, in: .common).autoconnect()

    var body: some View {
        CinematicContainer(
            vignette: true,
            bloom: true,
            motionBlur: false,
            grain: true
        ) {
            ZStack {
                // Battle arena background
                BattleArenaBackground()

                VStack(spacing: 0) {
                    // Top bar with close button
                    HStack {
                        closeButton
                        Spacer()
                        streakIndicator
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Boss section
                    bossSection
                        .shake(trigger: bossShake ? 1 : 0)

                    Spacer()

                    // Question and answers
                    if let question = currentQuestion, !gameEnded {
                        battleQuestionView(question)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Player section
                    playerSection
                        .shake(trigger: playerShake ? 1 : 0)
                        .padding(.bottom, 40)
                }

                // Damage indicators
                if showBossDamage {
                    DamageIndicator(damage: lastDamage, isPlayer: false)
                        .position(x: UIScreen.main.bounds.width / 2, y: 200)
                }

                if showPlayerDamage {
                    DamageIndicator(damage: lastDamage, isPlayer: true)
                        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 180)
                }

                // Game end overlay
                if gameEnded {
                    gameEndOverlay
                }
            }
            .ignoresSafeArea()
        }
        .task {
            await startGame()
        }
        .onReceive(bossAttackTimer) { _ in
            if !gameEnded && !showResult && currentQuestion != nil {
                bossAutoAttack()
            }
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
                        .fill(DesignSystem.Colors.elevated.opacity(0.8))
                )
        }
    }

    // MARK: - Streak Indicator

    private var streakIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundColor(streak > 0 ? DesignSystem.Colors.orange : DesignSystem.Colors.textMuted)
            Text("\(streak)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(streak > 0 ? DesignSystem.Colors.orange : DesignSystem.Colors.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground.opacity(0.8))
        )
    }

    // MARK: - Boss Section

    private var bossSection: some View {
        VStack(spacing: 12) {
            // Boss name and level
            HStack {
                Text(bossName)
                    .font(DesignSystem.Typography.cardTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Lv.\(currentBossLevel)")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.red.opacity(0.2))
                    )
            }

            // Boss HP bar
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.elevated)

                        // HP fill
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.red, Color(hex: "#FF3333")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geometry.size.width * CGFloat(bossHP) / CGFloat(bossMaxHP)))
                            .animation(.easeOut(duration: 0.3), value: bossHP)
                    }
                }
                .frame(height: 16)

                Text("\(bossHP) / \(bossMaxHP)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
            .padding(.horizontal, 40)

            // Boss sprite
            BossSpriteView(bossLevel: currentBossLevel, isHurt: bossShake)
                .frame(height: 160)
        }
        .padding(.top, 20)
    }

    // MARK: - Player Section

    private var playerSection: some View {
        VStack(spacing: 8) {
            // Player HP bar
            VStack(spacing: 4) {
                Text("\(playerHP) / \(playerMaxHP) HP")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textMuted)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignSystem.Colors.elevated)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.cyan, DesignSystem.Colors.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geometry.size.width * CGFloat(playerHP) / CGFloat(playerMaxHP)))
                            .animation(.easeOut(duration: 0.3), value: playerHP)
                    }
                }
                .frame(height: 12)
            }
            .padding(.horizontal, 60)

            // Player indicator
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.cyan)
                Text("You")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
    }

    // MARK: - Battle Question View

    private func battleQuestionView(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 16) {
            // Attack prompt
            Text("Choose your attack!")
                .font(DesignSystem.Typography.caption())
                .foregroundColor(DesignSystem.Colors.orange)

            // Question text
            Text(question.question.questionText)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, 16)

            // Answer buttons styled as attack options
            if question.question.isMultipleChoice {
                VStack(spacing: 10) {
                    ForEach(answerOptions, id: \.self) { answer in
                        AttackButton(
                            answer: answer,
                            isSelected: selectedAnswer == answer,
                            isCorrect: showResult ? (answer == question.question.correctAnswer ? true : (selectedAnswer == answer ? false : nil)) : nil,
                            isDisabled: showResult,
                            streak: streak
                        ) {
                            selectAnswer(answer)
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    SPRInputField(text: $sprAnswer, placeholder: "Enter answer") {
                        if !sprAnswer.isEmpty {
                            submitSPRAnswer()
                        }
                    }
                    .disabled(showResult)

                    if !showResult && !sprAnswer.isEmpty {
                        Button {
                            submitSPRAnswer()
                        } label: {
                            Text("Attack!")
                                .font(DesignSystem.Typography.button())
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(LinearGradient.primaryButton)
                                )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.cardBackground.opacity(0.95))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Game End Overlay

    private var gameEndOverlay: some View {
        VStack(spacing: 24) {
            if victory {
                Text("VICTORY!")
                    .font(DesignSystem.Typography.screenTitle())
                    .foregroundColor(DesignSystem.Colors.cyan)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.orange)
            } else {
                Text("DEFEATED")
                    .font(DesignSystem.Typography.screenTitle())
                    .foregroundColor(DesignSystem.Colors.red)

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.red)
            }

            VStack(spacing: 12) {
                StatRow(icon: "bolt.fill", label: "Total Damage", value: "\(totalDamageDealt)", color: DesignSystem.Colors.orange)
                StatRow(icon: "checkmark.circle.fill", label: "Correct Answers", value: "\(engine.correctAnswers)", color: DesignSystem.Colors.cyan)
                StatRow(icon: "flame.fill", label: "Best Streak", value: "\(engine.maxStreak)", color: DesignSystem.Colors.orange)
                StatRow(icon: "percent", label: "Accuracy", value: "\(Int(engine.accuracy))%", color: DesignSystem.Colors.blue)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            if victory {
                PrimaryButton(title: "Fight Next Boss") {
                    nextBoss()
                }
            }

            PrimaryButton(title: victory ? "Claim Victory" : "Try Again") {
                if victory {
                    dismiss()
                } else {
                    resetGame()
                }
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
            streak += 1

            // Calculate damage with streak bonus
            let baseDamage = 30
            let streakBonus = min(streak * 5, 50)
            let damage = baseDamage + streakBonus

            dealDamageToBoss(damage)
            showGlow = true
            popTrigger += 1
        } else {
            HapticsManager.shared.incorrectAnswer()
            streak = 0

            // Boss counter-attacks on wrong answer
            takeDamage(15)
            showError = true
            shakeTrigger += 1
        }

        showResult = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            advanceToNext()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showGlow = false
            showError = false
        }
    }

    private func dealDamageToBoss(_ damage: Int) {
        lastDamage = damage
        showBossDamage = true
        totalDamageDealt += damage

        withAnimation {
            bossHP = max(0, bossHP - damage)
            bossShake = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            bossShake = false
            showBossDamage = false
        }

        if bossHP <= 0 {
            victory = true
            endGame()
        }
    }

    private func takeDamage(_ damage: Int) {
        lastDamage = damage
        showPlayerDamage = true

        withAnimation {
            playerHP = max(0, playerHP - damage)
            playerShake = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            playerShake = false
            showPlayerDamage = false
        }

        if playerHP <= 0 {
            victory = false
            endGame()
        }
    }

    private func bossAutoAttack() {
        // Boss attacks if player takes too long
        takeDamage(10)
        HapticsManager.shared.timerWarning()
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
            // Ran out of questions - evaluate based on remaining HP
            victory = playerHP > 0 && bossHP <= bossMaxHP / 2
            endGame()
        }
    }

    private func endGame() {
        gameEnded = true
        sessionResult = engine.endSession()
        HapticsManager.shared.gameTransition()
    }

    private func nextBoss() {
        currentBossLevel += 1
        bossMaxHP = 500 + (currentBossLevel - 1) * 200
        bossHP = bossMaxHP
        bossName = getBossName(for: currentBossLevel)
        playerHP = min(playerHP + 30, playerMaxHP) // Heal slightly
        gameEnded = false
        victory = false
        streak = 0

        Task {
            await engine.loadQuestions()
            engine.configureSession(scope: scope, config: config)
            if let question = engine.startSession() {
                currentQuestion = question
                answerOptions = question.question.allAnswers
            }
        }
    }

    private func resetGame() {
        playerHP = playerMaxHP
        bossHP = bossMaxHP
        totalDamageDealt = 0
        streak = 0
        gameEnded = false
        victory = false
        selectedAnswer = nil
        answerResult = nil
        showResult = false
        sprAnswer = ""

        Task {
            await startGame()
        }
    }

    private func getBossName(for level: Int) -> String {
        let names = [
            "The Examinator",
            "Quiz Master",
            "Professor Puzzler",
            "The Riddler",
            "Dr. Difficulty",
            "The SAT Sage",
            "Grand Calculator",
            "The Final Boss"
        ]
        return names[min(level - 1, names.count - 1)]
    }
}

// MARK: - Battle Arena Background

struct BattleArenaBackground: View {
    var body: some View {
        ZStack {
            // Dark gradient
            LinearGradient(
                colors: [
                    Color(hex: "#1a0a20"),
                    Color(hex: "#0f0a15"),
                    DesignSystem.Colors.primaryBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Battle effects
            Circle()
                .fill(DesignSystem.Colors.red.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(y: -100)

            Circle()
                .fill(DesignSystem.Colors.primary.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(y: 200)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Boss Sprite View

struct BossSpriteView: View {
    let bossLevel: Int
    let isHurt: Bool

    var body: some View {
        ZStack {
            // Aura
            Circle()
                .fill(
                    RadialGradient(
                        colors: [bossColor.opacity(0.3), bossColor.opacity(0)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(isHurt ? 1.2 : 1.0)

            // Boss icon
            Image(systemName: bossIcon)
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(isHurt ? .white : bossColor)
                .scaleEffect(isHurt ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isHurt)
        }
    }

    private var bossIcon: String {
        switch bossLevel {
        case 1: return "brain.head.profile"
        case 2: return "book.closed.fill"
        case 3: return "lightbulb.fill"
        case 4: return "questionmark.diamond.fill"
        case 5: return "atom"
        case 6: return "graduationcap.fill"
        case 7: return "function"
        default: return "crown.fill"
        }
    }

    private var bossColor: Color {
        switch bossLevel {
        case 1: return DesignSystem.Colors.red
        case 2: return DesignSystem.Colors.orange
        case 3: return Color(hex: "#FFD700")
        case 4: return DesignSystem.Colors.primary
        case 5: return DesignSystem.Colors.cyan
        case 6: return DesignSystem.Colors.blue
        case 7: return Color(hex: "#FF69B4")
        default: return Color(hex: "#FFD700")
        }
    }
}

// MARK: - Attack Button

struct AttackButton: View {
    let answer: String
    let isSelected: Bool
    let isCorrect: Bool?
    let isDisabled: Bool
    let streak: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: attackIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(iconColor)

                Text(answer)
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(textColor)
                    .lineLimit(2)

                Spacer()

                if streak > 0 && isCorrect == nil {
                    Text("+\(30 + min(streak * 5, 50))")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .disabled(isDisabled)
    }

    private var attackIcon: String {
        if let correct = isCorrect {
            return correct ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        return "bolt.fill"
    }

    private var iconColor: Color {
        if let correct = isCorrect {
            return correct ? DesignSystem.Colors.cyan : DesignSystem.Colors.red
        }
        return DesignSystem.Colors.orange
    }

    private var textColor: Color {
        if let correct = isCorrect {
            return correct ? DesignSystem.Colors.cyan : DesignSystem.Colors.red
        }
        return DesignSystem.Colors.textPrimary
    }

    private var backgroundColor: Color {
        if let correct = isCorrect {
            return correct ? DesignSystem.Colors.cyan.opacity(0.15) : DesignSystem.Colors.red.opacity(0.15)
        }
        return isSelected ? DesignSystem.Colors.elevated : DesignSystem.Colors.cardBackground.opacity(0.8)
    }

    private var borderColor: Color {
        if let correct = isCorrect {
            return correct ? DesignSystem.Colors.cyan : DesignSystem.Colors.red
        }
        return isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBorder
    }
}

// MARK: - Damage Indicator

struct DamageIndicator: View {
    let damage: Int
    let isPlayer: Bool
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        Text("-\(damage)")
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(isPlayer ? DesignSystem.Colors.red : DesignSystem.Colors.orange)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    offset = -50
                    opacity = 0
                }
            }
    }
}
