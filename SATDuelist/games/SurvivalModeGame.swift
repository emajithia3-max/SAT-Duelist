import SwiftUI

// MARK: - Survival Mode Game
// Ends on first wrong answer - high tension visuals
// Per Minigame.md runtime contract

struct SurvivalModeGame: View {
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
    @State private var livesRemaining = 1  // Survival = 1 life
    @State private var showDeathAnimation = false

    // Answer options for MCQ
    @State private var answerOptions: [String] = []

    // Tension level increases with streak
    private var tensionLevel: Double {
        min(1.0, Double(engine.currentStreak) / 10.0)
    }

    var body: some View {
        CinematicSurvival {
            ZStack {
                VStack(spacing: 0) {
                    // Header
                    gameHeader

                    Spacer()

                    // Question Card
                    if let question = currentQuestion {
                        questionContent(question)
                            .cardTransition(isPresented: isCardPresented)
                            .shake(trigger: shakeTrigger)
                            .scalePop(trigger: popTrigger)
                            .pulseGlow(isActive: showGlow)
                            .errorFlash(isActive: showError)
                            .padding(.horizontal, 20)
                    } else if engine.isLoading {
                        loadingView
                    } else if gameEnded, let result = sessionResult {
                        survivalSummary(result: result)
                            .padding(.horizontal, 20)
                    }

                    Spacer()

                    // Bottom stats
                    if !gameEnded {
                        bottomStats
                    }
                }
                .padding(.vertical, 20)

                // Death overlay
                if showDeathAnimation {
                    deathOverlay
                }
            }
        }
        .task {
            await startGame()
        }
    }

    // MARK: - Game Header

    private var gameHeader: some View {
        HStack {
            // Close button
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
                            .fill(DesignSystem.Colors.elevated)
                    )
            }

            Spacer()

            // Lives indicator
            HStack(spacing: 4) {
                Image(systemName: livesRemaining > 0 ? "heart.fill" : "heart.slash.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(livesRemaining > 0 ? DesignSystem.Colors.red : DesignSystem.Colors.textMuted)

                Text("SURVIVAL")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }

            Spacer()

            // Streak (survival score)
            VStack(spacing: 2) {
                Text("\(engine.correctAnswers)")
                    .font(DesignSystem.Typography.number())
                    .foregroundColor(DesignSystem.Colors.orange)

                Text("survived")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Question Content

    @ViewBuilder
    private func questionContent(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 20) {
            // Tension indicator
            if engine.correctAnswers > 0 {
                tensionBar
            }

            // Question card
            QuestionCardView(question: question)

            // Answer area
            if question.question.isMultipleChoice {
                mcqAnswers(question)
            } else {
                sprInput(question)
            }

            // Result feedback (only on wrong answer)
            if showResult, let result = answerResult, !result.isCorrect {
                resultFeedback(result)
            }
        }
    }

    // MARK: - Tension Bar

    private var tensionBar: some View {
        VStack(spacing: 4) {
            ProgressBar(
                progress: tensionLevel,
                color: tensionColor,
                height: 6
            )

            HStack {
                Text("TENSION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textMuted)

                Spacer()

                Text("\(engine.correctAnswers) streak")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(tensionColor)
            }
        }
        .padding(.horizontal, 4)
    }

    private var tensionColor: Color {
        if tensionLevel >= 0.8 {
            return DesignSystem.Colors.red
        } else if tensionLevel >= 0.5 {
            return DesignSystem.Colors.orange
        }
        return DesignSystem.Colors.cyan
    }

    // MARK: - MCQ Answers

    private func mcqAnswers(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(answerOptions, id: \.self) { answer in
                AnswerButton(
                    answer: answer,
                    isSelected: selectedAnswer == answer,
                    isCorrect: showResult ? (answer == question.question.correctAnswer ? true : (selectedAnswer == answer ? false : nil)) : nil,
                    isDisabled: showResult
                ) {
                    selectAnswer(answer)
                }
            }
        }
    }

    // MARK: - SPR Input

    private func sprInput(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 12) {
            SPRInputField(
                text: $sprAnswer,
                placeholder: "Enter your answer carefully..."
            ) {
                if !sprAnswer.isEmpty {
                    submitSPRAnswer()
                }
            }
            .disabled(showResult)

            if !showResult && !sprAnswer.isEmpty {
                PrimaryButton(title: "Submit") {
                    submitSPRAnswer()
                }
            }
        }
    }

    // MARK: - Result Feedback

    private func resultFeedback(_ result: AnswerResult) -> some View {
        CardView(showGlow: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.red)

                    Text("Game Over")
                        .font(DesignSystem.Typography.cardTitle())
                        .foregroundColor(DesignSystem.Colors.red)
                }

                Text("Correct answer: \(result.correctAnswer)")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text(result.explanation)
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .lineSpacing(3)

                PrimaryButton(title: "See Results") {
                    endGame()
                }
                .padding(.top, 8)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Death Overlay

    private var deathOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.red)

                Text("ELIMINATED")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.red)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Survival Summary

    private func survivalSummary(result: SessionResult) -> some View {
        CardView {
            VStack(spacing: 24) {
                // Title based on performance
                VStack(spacing: 8) {
                    Text(survivalTitle(for: result.correctCount))
                        .font(DesignSystem.Typography.screenTitle())
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("You survived \(result.correctCount) questions")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Big streak number
                VStack(spacing: 4) {
                    Text("\(result.correctCount)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.orange)

                    Text("STREAK")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                }

                // XP earned
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)

                    Text("+\(result.xpEarned) XP")
                        .font(DesignSystem.Typography.number())
                        .foregroundColor(DesignSystem.Colors.primary)
                }

                // Done button
                PrimaryButton(title: "Done") {
                    dismiss()
                }
            }
        }
    }

    private func survivalTitle(for streak: Int) -> String {
        switch streak {
        case 0:
            return "Better Luck Next Time"
        case 1...3:
            return "Good Try!"
        case 4...7:
            return "Nice Run!"
        case 8...12:
            return "Impressive!"
        case 13...20:
            return "Outstanding!"
        default:
            return "LEGENDARY!"
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                .scaleEffect(1.5)

            Text("Preparing survival challenge...")
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
    }

    // MARK: - Bottom Stats

    private var bottomStats: some View {
        HStack(spacing: 24) {
            // Current streak (main focus)
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 24))
                    Text("\(engine.correctAnswers)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.orange)
                }

                Text("Current Streak")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
        }
        .padding(.horizontal, 20)
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
            showGlow = true
            popTrigger += 1

            if engine.currentStreak > 1 {
                HapticsManager.shared.streakIncrement()
            }

            // Auto-advance on correct
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                advanceToNext()
            }
        } else {
            // GAME OVER
            livesRemaining = 0
            HapticsManager.shared.incorrectAnswer()
            showError = true
            shakeTrigger += 1

            // Show death animation briefly
            withAnimation(.easeIn(duration: 0.2)) {
                showDeathAnimation = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showDeathAnimation = false
                }
            }

            withAnimation(DesignSystem.Animation.spring) {
                showResult = true
            }
        }

        // Reset visual effects
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showGlow = false
            showError = false
        }
    }

    private func advanceToNext() {
        if engine.hasMoreQuestions {
            withAnimation(DesignSystem.Animation.spring) {
                isCardPresented = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                selectedAnswer = nil
                answerResult = nil
                showResult = false
                sprAnswer = ""

                if let question = engine.nextQuestion() {
                    currentQuestion = question
                    answerOptions = question.question.allAnswers

                    withAnimation(DesignSystem.Animation.spring) {
                        isCardPresented = true
                    }
                }
            }
        } else {
            // No more questions - player wins!
            endGame()
        }
    }

    private func endGame() {
        withAnimation(DesignSystem.Animation.spring) {
            sessionResult = engine.endSession()
            gameEnded = true
            isCardPresented = false
        }
        HapticsManager.shared.gameTransition()
    }
}
