import Foundation

// MARK: - Question Loader
// Loads all question JSON files from the bundle
// Tolerates malformed files (per Minigame.md)

final class QuestionLoader {

    // Singleton instance
    static let shared = QuestionLoader()

    // Cached questions
    private var cachedQuestions: [LoadedQuestion] = []
    private var isLoaded = false

    private init() {}

    // MARK: - Public API

    /// Load all questions from the question bank
    /// Non-blocking, can be called from background thread
    func loadAllQuestions() async -> [LoadedQuestion] {
        if isLoaded {
            return cachedQuestions
        }

        var allQuestions: [LoadedQuestion] = []

        // Get all JSON files from the question bank directory
        guard let bankURL = Bundle.main.url(forResource: "sat_question_bank", withExtension: nil) else {
            // Fallback: try to find individual JSON files in the bundle
            allQuestions = loadQuestionsFromBundle()
            cachedQuestions = allQuestions
            isLoaded = true
            return allQuestions
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: bankURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for fileURL in fileURLs where fileURL.pathExtension == "json" {
                if let questions = loadQuestionsFromFile(at: fileURL) {
                    allQuestions.append(contentsOf: questions)
                }
            }
        } catch {
            print("QuestionLoader: Error reading question bank directory: \(error)")
        }

        // Fallback if directory approach fails
        if allQuestions.isEmpty {
            allQuestions = loadQuestionsFromBundle()
        }

        cachedQuestions = allQuestions
        isLoaded = true
        return allQuestions
    }

    /// Synchronous version for when you need immediate access
    func loadAllQuestionsSync() -> [LoadedQuestion] {
        if isLoaded {
            return cachedQuestions
        }

        let questions = loadQuestionsFromBundle()
        cachedQuestions = questions
        isLoaded = true
        return questions
    }

    /// Clear cache and reload
    func reload() async -> [LoadedQuestion] {
        isLoaded = false
        cachedQuestions = []
        return await loadAllQuestions()
    }

    // MARK: - Private Helpers

    private func loadQuestionsFromBundle() -> [LoadedQuestion] {
        var allQuestions: [LoadedQuestion] = []

        // List of expected JSON files based on Author.md topics
        let jsonFiles = [
            // Reading and Writing
            "rw_words_in_context",
            "rw_text_structure_purpose",
            "rw_cross_text_connections",
            "rw_central_ideas_details",
            "rw_command_of_evidence",
            "rw_quantitative_information",
            "rw_sentence_boundaries",
            "rw_form_structure_sense",
            "rw_rhetorical_synthesis",
            "rw_transitions",
            // Math - Algebra
            "math_linear_equations_one_variable",
            "math_linear_equations_two_variables",
            "math_linear_functions",
            "math_systems_linear_equations",
            "math_linear_inequalities",
            // Math - Advanced Math
            "math_equivalent_expressions",
            "math_nonlinear_equations",
            "math_systems_nonlinear_equations",
            "math_nonlinear_functions",
            // Math - Problem Solving and Data Analysis
            "math_ratios_rates",
            "math_percentages",
            "math_units_conversions",
            "math_one_variable_data",
            "math_two_variable_data",
            "math_probability",
            "math_statistical_inference",
            "math_evaluating_statistical_claims",
            // Math - Geometry and Trigonometry
            "math_area_volume",
            "math_lines_angles",
            "math_triangles",
            "math_right_triangle_trig",
            "math_circles"
        ]

        for fileName in jsonFiles {
            if let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
               let questions = loadQuestionsFromFile(at: url) {
                allQuestions.append(contentsOf: questions)
            }
        }

        return allQuestions
    }

    private func loadQuestionsFromFile(at url: URL) -> [LoadedQuestion]? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let bankFile = try decoder.decode(QuestionBankFile.self, from: data)

            // Validate and convert to LoadedQuestion
            return bankFile.questions.compactMap { question -> LoadedQuestion? in
                // Validate MCQ has exactly 3 wrong answers
                if question.questionType == .multipleChoice && question.wrongAnswers.count != 3 {
                    print("QuestionLoader: Skipping invalid MCQ \(question.id) - wrong answer count")
                    return nil
                }

                // Validate SPR has empty wrong answers
                if question.questionType == .studentProducedResponse && !question.wrongAnswers.isEmpty {
                    print("QuestionLoader: Skipping invalid SPR \(question.id) - has wrong answers")
                    return nil
                }

                return LoadedQuestion(
                    id: question.id,
                    section: bankFile.section,
                    topic: bankFile.topic,
                    question: question
                )
            }
        } catch {
            // Gracefully handle malformed files (per Minigame.md)
            print("QuestionLoader: Error loading \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
