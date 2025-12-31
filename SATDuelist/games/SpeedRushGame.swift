import SwiftUI

// MARK: - Speed Rush Game
// Timer-driven, fast motion with emphasized blur
// Per Minigame.md runtime contract

struct SpeedRushGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Default time limit: 60 seconds
    private let timeLimit: TimeInterval

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
    @State private var motionBlur = false

    // Timer
    @State private var timeRemaining: TimeInterval
    @State private var timerActive = false
    @State private var showTimerWarning = false

    // Answer options for MCQ
    @State private var answerOptions: [String] = []

    init(scope: ScopeSelection, config: SessionConfig) {
        self.scope = scope
        self.config = config
        self.timeLimit = config.timeLimit ?? 60
        _timeRemaining = State(initialValue: config.timeLimit ?? 60)
    }

    var body: some View {
        CinematicContainer(
            vignette: true,
            bloom: true,
            motionBlur: motionBlur,
            grain: false,
            motionBlurIntensity: 0.5
        ) {
            VStack(spacing: 0) {
                // Header with timer
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
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            updateTimer()
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

            // Timer
            timerView

            Spacer()

            // Score
            Text("\(engine.correctAnswers)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.primary)
                +
            Text(" pts")
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Timer View

    private var timerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(timerColor)

            Text(formatTime(timeRemaining))
                .font(DesignSystem.Typography.number())
                .foregroundColor(timerColor)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(timerColor.opacity(0.15))
        )
        .scaleEffect(showTimerWarning ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: showTimerWarning)
    }

    private var timerColor: Color {
        if timeRemaining <= 10 {
            return DesignSystem.Colors.red
        } else if timeRemaining <= 20 {
            return DesignSystem.Colors.orange
        }
        return DesignSystem.Colors.cyan
    }

    // MARK: - Question Content

    @ViewBuilder
    private func questionContent(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 20) {
            // Question card (compact for speed)
            QuestionCardView(question: question, showDifficulty: false)

            // Answer area
            if question.question.isMultipleChoice {
                mcqAnswers(question)
            } else {
                sprInput(question)
            }
        }
    }

    // MARK: - MCQ Answers

    private func mcqAnswers(_ question: LoadedQuestion) -> some View {
        VStack(spacing: 10) {
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
        HStack(spacing: 12) {
            SPRInputField(
                text: $sprAnswer,
                placeholder: "Answer"
            ) {
                if !sprAnswer.isEmpty {
                    submitSPRAnswer()
                }
            }
            .disabled(showResult)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                .scaleEffect(1.5)

            Text("Get ready...")
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
    }

    // MARK: - Bottom Stats

    private var bottomStats: some View {
        HStack(spacing: 24) {
            // Questions answered
            VStack(spacing: 4) {
                Text("\(engine.questionsAnswered)")
                    .font(DesignSystem.Typography.number())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Answered")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }

            // Streak
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("🔥")
                    Text("\(engine.currentStreak)")
                        .font(DesignSystem.Typography.number())
                        .foregroundColor(DesignSystem.Colors.orange)
                }

                Text("Streak")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }

            // Accuracy
            VStack(spacing: 4) {
                Text("\(Int(engine.accuracy))%")
                    .font(DesignSystem.Typography.number())
                    .foregroundColor(DesignSystem.Colors.blue)

                Text("Accuracy")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Timer Logic

    private func updateTimer() {
        guard timerActive && !gameEnded else { return }

        if timeRemaining > 0 {
            timeRemaining -= 0.1

            // Warning at 10 seconds
            if timeRemaining <= 10 && !showTimerWarning {
                showTimerWarning = true
                HapticsManager.shared.timerWarning()
            }
        } else {
            endGame()
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let secs = max(0, Int(seconds))
        let mins = secs / 60
        let remainingSecs = secs % 60
        return String(format: "%d:%02d", mins, remainingSecs)
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

            // Start timer after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                timerActive = true
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

        // Trigger motion blur on transition
        motionBlur = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            motionBlur = false
        }

        if result.isCorrect {
            HapticsManager.shared.correctAnswer()
            showGlow = true
            popTrigger += 1
        } else {
            HapticsManager.shared.incorrectAnswer()
            showError = true
            shakeTrigger += 1
        }

        showResult = true

        // Quick auto-advance for speed mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            advanceToNext()
        }

        // Reset visual effects
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showGlow = false
            showError = false
        }
    }

    private func advanceToNext() {
        if engine.hasMoreQuestions && timeRemaining > 0 {
            withAnimation(.easeOut(duration: 0.15)) {
                isCardPresented = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                selectedAnswer = nil
                answerResult = nil
                showResult = false
                sprAnswer = ""

                if let question = engine.nextQuestion() {
                    currentQuestion = question
                    answerOptions = question.question.allAnswers

                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isCardPresented = true
                    }
                }
            }
        } else {
            endGame()
        }
    }

    private func endGame() {
        timerActive = false

        withAnimation(DesignSystem.Animation.spring) {
            sessionResult = engine.endSession()
            gameEnded = true
            isCardPresented = false
        }

        HapticsManager.shared.gameTransition()
    }
}
