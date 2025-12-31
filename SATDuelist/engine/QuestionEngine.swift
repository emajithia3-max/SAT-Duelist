import Foundation
import Combine

// MARK: - Question Engine
// Main engine for question delivery (per Minigame.md)
// Supports scoping, randomization, and session management

@MainActor
final class QuestionEngine: ObservableObject {

    // MARK: - Published State
    @Published private(set) var isLoading = true
    @Published private(set) var currentQuestion: LoadedQuestion?
    @Published private(set) var questionsRemaining: Int = 0
    @Published private(set) var questionsAnswered: Int = 0
    @Published private(set) var correctAnswers: Int = 0
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var maxStreak: Int = 0
    @Published private(set) var hasError = false
    @Published private(set) var errorMessage: String?

    // MARK: - Private State
    private var allQuestions: [LoadedQuestion] = []
    private var questionPool: [LoadedQuestion] = []
    private var usedQuestionIds: Set<String> = []
    private var scope: ScopeSelection = .all
    private var config: SessionConfig = .default
    private var sessionStartTime: Date?
    private var missedSkills: [String] = []
    private var topicBreakdown: [String: Int] = [:]

    // MARK: - Initialization

    init() {}

    // MARK: - Public API

    /// Load questions from the bank
    func loadQuestions() async {
        isLoading = true
        hasError = false
        errorMessage = nil

        allQuestions = await QuestionLoader.shared.loadAllQuestions()

        if allQuestions.isEmpty {
            hasError = true
            errorMessage = "No questions available. Please check the question bank."
        }

        isLoading = false
    }

    /// Configure a new session with scope and settings
    func configureSession(scope: ScopeSelection, config: SessionConfig = .default) {
        self.scope = scope
        self.config = config

        // Reset session state
        usedQuestionIds.removeAll()
        questionsAnswered = 0
        correctAnswers = 0
        currentStreak = 0
        maxStreak = 0
        missedSkills.removeAll()
        topicBreakdown.removeAll()
        sessionStartTime = nil
        currentQuestion = nil

        // Build question pool
        questionPool = ScopeResolver.resolve(
            questions: allQuestions,
            scope: scope,
            config: config
        )

        questionsRemaining = questionPool.count

        if questionPool.isEmpty {
            hasError = true
            errorMessage = "No questions match the selected scope."
        } else {
            hasError = false
            errorMessage = nil
        }
    }

    /// Start the session and get the first question
    func startSession() -> LoadedQuestion? {
        sessionStartTime = Date()
        return nextQuestion()
    }

    /// Get the next random question
    func nextQuestion() -> LoadedQuestion? {
        // Filter out used questions
        let available = questionPool.filter { !usedQuestionIds.contains($0.id) }

        if available.isEmpty {
            // Pool exhausted
            currentQuestion = nil
            return nil
        }

        // Random selection
        let selected = available.randomElement()!
        usedQuestionIds.insert(selected.id)
        questionsRemaining = questionPool.count - usedQuestionIds.count
        currentQuestion = selected

        return selected
    }

    /// Submit an answer and get feedback
    func submitAnswer(_ answer: String) -> AnswerResult {
        guard let question = currentQuestion else {
            return AnswerResult(isCorrect: false, correctAnswer: "", explanation: "")
        }

        questionsAnswered += 1

        // Check answer
        let isCorrect = checkAnswer(answer, against: question.question)

        if isCorrect {
            correctAnswers += 1
            currentStreak += 1
            maxStreak = max(maxStreak, currentStreak)
        } else {
            currentStreak = 0
            missedSkills.append(question.question.skill)
        }

        // Track topic breakdown
        topicBreakdown[question.topic, default: 0] += 1

        return AnswerResult(
            isCorrect: isCorrect,
            correctAnswer: question.question.correctAnswer,
            explanation: question.question.explanation
        )
    }

    /// End the session and get results
    func endSession() -> SessionResult {
        let timeSpent = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        return SessionResult(
            totalAnswered: questionsAnswered,
            correctCount: correctAnswers,
            accuracy: questionsAnswered > 0 ? Double(correctAnswers) / Double(questionsAnswered) : 0,
            maxStreak: maxStreak,
            timeSpent: timeSpent,
            perTopicBreakdown: topicBreakdown.isEmpty ? nil : topicBreakdown,
            missedSkills: missedSkills.isEmpty ? nil : Array(Set(missedSkills))
        )
    }

    /// Check if more questions are available
    var hasMoreQuestions: Bool {
        questionsRemaining > 0
    }

    /// Get current accuracy percentage
    var accuracy: Double {
        guard questionsAnswered > 0 else { return 0 }
        return Double(correctAnswers) / Double(questionsAnswered) * 100
    }

    /// Get scope counts for UI
    func getScopeCounts() -> ScopeCounts {
        ScopeResolver.questionCounts(from: allQuestions)
    }

    /// Get available topics for a section
    func getTopics(for section: SATSection) -> [String] {
        ScopeResolver.availableTopics(from: allQuestions, for: section)
    }

    // MARK: - Private Helpers

    private func checkAnswer(_ submitted: String, against question: Question) -> Bool {
        let submittedNormalized = normalizeAnswer(submitted)
        let correctNormalized = normalizeAnswer(question.correctAnswer)

        return submittedNormalized == correctNormalized
    }

    private func normalizeAnswer(_ answer: String) -> String {
        answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

// MARK: - Answer Result
struct AnswerResult {
    let isCorrect: Bool
    let correctAnswer: String
    let explanation: String
}
