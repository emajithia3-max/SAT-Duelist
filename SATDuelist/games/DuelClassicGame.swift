import SwiftUI

// MARK: - Duel Classic Game
// Card-based gameplay with streaks and XP
// Per Minigame.md runtime contract

struct DuelClassicGame: View {
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

    // Answer options for MCQ
    @State private var answerOptions: [String] = []

    var body: some View {
        CinematicContainer.duelClassic {
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
                    // Game ended - show summary
                    SessionSummaryCard(result: result) {
                        dismiss()
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Bottom stats
                if !gameEnded {
                    bottomStats
                }
            }
            .padding(.vertical, 20)
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

            // Streak counter
            StreakCounter(streak: engine.currentStreak, animate: true)

            Spacer()

            // Question counter
            Text("\(engine.questionsAnswered + 1)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                +
            Text(" / \(engine.questionsAnswered + engine.questionsRemaining + 1)")
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Question Content

    @ViewBuilder
    private func questionContent(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 20) {
            // Question card
            QuestionCardView(question: question)

            // Answer area
            if question.question.isMultipleChoice {
                mcqAnswers(question)
            } else {
                sprInput(question)
            }

            // Result feedback
            if showResult, let result = answerResult {
                resultFeedback(result)
            }

            // Continue button (after answering)
            if showResult {
                continueButton
            }
        }
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
                placeholder: "Enter your answer"
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
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(result.isCorrect ? DesignSystem.Colors.cyan : DesignSystem.Colors.red)

                    Text(result.isCorrect ? "Correct!" : "Incorrect")
                        .font(DesignSystem.Typography.cardTitle())
                        .foregroundColor(result.isCorrect ? DesignSystem.Colors.cyan : DesignSystem.Colors.red)
                }

                if !result.isCorrect {
                    Text("Correct answer: \(result.correctAnswer)")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Text(result.explanation)
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .lineSpacing(3)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        PrimaryButton(
            title: engine.hasMoreQuestions ? "Next Question" : "See Results"
        ) {
            advanceToNext()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                .scaleEffect(1.5)

            Text("Loading questions...")
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
    }

    // MARK: - Bottom Stats

    private var bottomStats: some View {
        HStack(spacing: 24) {
            // Accuracy
            VStack(spacing: 4) {
                Text("\(Int(engine.accuracy))%")
                    .font(DesignSystem.Typography.number())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Accuracy")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }

            // XP
            VStack(spacing: 4) {
                Text("\(engine.correctAnswers * 10)")
                    .font(DesignSystem.Typography.number())
                    .foregroundColor(DesignSystem.Colors.primary)

                Text("XP")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }

            // Max Streak
            VStack(spacing: 4) {
                Text("\(engine.maxStreak)")
                    .font(DesignSystem.Typography.number())
                    .foregroundColor(DesignSystem.Colors.orange)

                Text("Best Streak")
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

        // Auto-submit for MCQ
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
        } else {
            HapticsManager.shared.incorrectAnswer()
            showError = true
            shakeTrigger += 1

            if engine.currentStreak == 0 && engine.maxStreak > 0 {
                HapticsManager.shared.streakLost()
            }
        }

        withAnimation(DesignSystem.Animation.spring) {
            showResult = true
        }

        // Reset visual effects
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showGlow = false
            showError = false
        }
    }

    private func advanceToNext() {
        HapticsManager.shared.buttonPress()

        if engine.hasMoreQuestions {
            // Transition to next question
            withAnimation(DesignSystem.Animation.spring) {
                isCardPresented = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
            // End game
            withAnimation(DesignSystem.Animation.spring) {
                sessionResult = engine.endSession()
                gameEnded = true
                isCardPresented = false
            }
            HapticsManager.shared.gameTransition()
        }
    }
}

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticsManager.shared.buttonPress()
            action()
        }) {
            Text(title)
                .font(DesignSystem.Typography.button())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(LinearGradient.primaryButton)
                )
                .buttonGlow()
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Session Summary Card

struct SessionSummaryCard: View {
    let result: SessionResult
    let onDismiss: () -> Void

    var body: some View {
        CardView {
            VStack(spacing: 24) {
                // Title
                Text("Session Complete!")
                    .font(DesignSystem.Typography.screenTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    StatItem(
                        icon: "checkmark.circle.fill",
                        value: "\(result.correctCount)/\(result.totalAnswered)",
                        label: "Correct",
                        color: DesignSystem.Colors.cyan
                    )

                    StatItem(
                        icon: "percent",
                        value: "\(Int(result.accuracy * 100))%",
                        label: "Accuracy",
                        color: DesignSystem.Colors.blue
                    )

                    StatItem(
                        icon: "flame.fill",
                        value: "\(result.maxStreak)",
                        label: "Best Streak",
                        color: DesignSystem.Colors.orange
                    )

                    StatItem(
                        icon: "star.fill",
                        value: "\(result.xpEarned)",
                        label: "XP Earned",
                        color: DesignSystem.Colors.primary
                    )
                }

                // Time spent
                Text("Time: \(formatTime(result.timeSpent))")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textMuted)

                // Done button
                PrimaryButton(title: "Done") {
                    onDismiss()
                }
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(label)
                .font(DesignSystem.Typography.caption())
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}
