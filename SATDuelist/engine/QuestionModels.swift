import Foundation

// MARK: - Section Enum (per Author.md)
enum SATSection: String, Codable, CaseIterable {
    case readingAndWriting = "Reading and Writing"
    case math = "Math"

    var displayName: String {
        rawValue
    }
}

// MARK: - Question Type Enum (per Author.md)
enum QuestionType: String, Codable {
    case multipleChoice = "multiple_choice"
    case studentProducedResponse = "student_produced_response"

    var displayName: String {
        switch self {
        case .multipleChoice: return "Multiple Choice"
        case .studentProducedResponse: return "Free Response"
        }
    }
}

// MARK: - Difficulty Enum (per Author.md)
enum Difficulty: String, Codable {
    case easy
    case medium
    case hard

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .easy: return "#3FE0C5"    // Cyan
        case .medium: return "#FF9F43"  // Orange
        case .hard: return "#FF5D5D"    // Red
        }
    }
}

// MARK: - Question Model (per Author.md schema)
struct Question: Codable, Identifiable, Equatable {
    let id: String
    let questionType: QuestionType
    let difficulty: Difficulty
    let skill: String
    let question: String
    let correctAnswer: String
    let wrongAnswers: [String]
    let explanation: String

    // Computed: All answer choices shuffled (for MCQ)
    var allAnswers: [String] {
        var answers = wrongAnswers
        answers.append(correctAnswer)
        return answers.shuffled()
    }

    // Check if MCQ
    var isMultipleChoice: Bool {
        questionType == .multipleChoice
    }

    // Check if SPR
    var isStudentProducedResponse: Bool {
        questionType == .studentProducedResponse
    }

    enum CodingKeys: String, CodingKey {
        case id
        case questionType = "question_type"
        case difficulty
        case skill
        case question
        case correctAnswer = "correct_answer"
        case wrongAnswers = "wrong_answers"
        case explanation
    }

    static func == (lhs: Question, rhs: Question) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Question Bank File Model (per Author.md schema)
struct QuestionBankFile: Codable {
    let meta: String
    let section: SATSection
    let topic: String
    let exam: String
    let year: Int
    let questions: [Question]

    enum CodingKeys: String, CodingKey {
        case meta = "_meta"
        case section
        case topic
        case exam
        case year
        case questions
    }
}

// MARK: - Loaded Question (enriched with file metadata)
struct LoadedQuestion: Identifiable, Equatable {
    let id: String
    let section: SATSection
    let topic: String
    let question: Question

    static func == (lhs: LoadedQuestion, rhs: LoadedQuestion) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Scope Selection (per Minigame.md)
struct ScopeSelection: Equatable {
    let anythingGoes: Bool
    let section: SATSection?
    let topic: String?

    static let all = ScopeSelection(anythingGoes: true, section: nil, topic: nil)

    static func sectionOnly(_ section: SATSection) -> ScopeSelection {
        ScopeSelection(anythingGoes: false, section: section, topic: nil)
    }

    static func topicSpecific(section: SATSection, topic: String) -> ScopeSelection {
        ScopeSelection(anythingGoes: false, section: section, topic: topic)
    }
}

// MARK: - Session Configuration (per Minigame.md)
struct SessionConfig {
    let questionCount: Int?
    let timeLimit: TimeInterval?
    let allowSPR: Bool

    static let `default` = SessionConfig(questionCount: nil, timeLimit: nil, allowSPR: true)

    static func timed(_ seconds: TimeInterval) -> SessionConfig {
        SessionConfig(questionCount: nil, timeLimit: seconds, allowSPR: true)
    }

    static func counted(_ count: Int) -> SessionConfig {
        SessionConfig(questionCount: count, timeLimit: nil, allowSPR: true)
    }
}

// MARK: - Session Result (per Minigame.md)
struct SessionResult {
    let totalAnswered: Int
    let correctCount: Int
    let accuracy: Double
    let maxStreak: Int
    let timeSpent: TimeInterval
    let perTopicBreakdown: [String: Int]?
    let missedSkills: [String]?

    var incorrectCount: Int {
        totalAnswered - correctCount
    }

    var xpEarned: Int {
        // Base XP: 10 per correct answer
        // Streak bonus: +5 per streak beyond 3
        var xp = correctCount * 10
        if maxStreak >= 3 {
            xp += (maxStreak - 2) * 5
        }
        return xp
    }
}

// MARK: - Canonical Topics Registry (per Author.md)
struct TopicsRegistry {

    // Reading and Writing Topics
    static let readingAndWritingTopics: [String] = [
        // Craft and Structure
        "Words in Context",
        "Text Structure and Purpose",
        "Cross-Text Connections",
        // Information and Ideas
        "Central Ideas and Details",
        "Command of Evidence",
        "Quantitative Information",
        // Standard English Conventions
        "Sentence Boundaries",
        "Form, Structure, and Sense",
        // Expression of Ideas
        "Rhetorical Synthesis",
        "Transitions"
    ]

    // Math Topics
    static let mathTopics: [String] = [
        // Algebra
        "Linear Equations in One Variable",
        "Linear Equations in Two Variables",
        "Linear Functions",
        "Systems of Linear Equations",
        "Linear Inequalities",
        // Advanced Math
        "Equivalent Expressions",
        "Nonlinear Equations",
        "Systems of Nonlinear Equations",
        "Nonlinear Functions",
        // Problem Solving and Data Analysis
        "Ratios and Rates",
        "Percentages",
        "Units and Conversions",
        "One-Variable Data",
        "Two-Variable Data",
        "Probability",
        "Statistical Inference",
        "Evaluating Statistical Claims",
        // Geometry and Trigonometry
        "Area and Volume",
        "Lines and Angles",
        "Triangles",
        "Right Triangle Trigonometry",
        "Circles"
    ]

    static func topics(for section: SATSection) -> [String] {
        switch section {
        case .readingAndWriting:
            return readingAndWritingTopics
        case .math:
            return mathTopics
        }
    }

    static var allTopics: [String] {
        readingAndWritingTopics + mathTopics
    }
}
