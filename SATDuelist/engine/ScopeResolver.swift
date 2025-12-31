import Foundation

// MARK: - Scope Resolver
// Filters questions based on scope selection (per Minigame.md)

final class ScopeResolver {

    // MARK: - Public API

    /// Filter questions based on scope selection
    static func resolve(
        questions: [LoadedQuestion],
        scope: ScopeSelection,
        config: SessionConfig = .default
    ) -> [LoadedQuestion] {
        var filtered = questions

        // Apply scope filtering
        if !scope.anythingGoes {
            // Filter by section if specified
            if let section = scope.section {
                filtered = filtered.filter { $0.section == section }
            }

            // Filter by topic if specified
            if let topic = scope.topic {
                filtered = filtered.filter { $0.topic == topic }
            }
        }

        // Filter by question type if SPR not allowed
        if !config.allowSPR {
            filtered = filtered.filter { $0.question.isMultipleChoice }
        }

        return filtered
    }

    /// Get available sections from a set of questions
    static func availableSections(from questions: [LoadedQuestion]) -> [SATSection] {
        let sections = Set(questions.map { $0.section })
        return Array(sections).sorted { $0.rawValue < $1.rawValue }
    }

    /// Get available topics for a section from a set of questions
    static func availableTopics(
        from questions: [LoadedQuestion],
        for section: SATSection
    ) -> [String] {
        let topics = Set(
            questions
                .filter { $0.section == section }
                .map { $0.topic }
        )
        return Array(topics).sorted()
    }

    /// Get question count for each scope option
    static func questionCounts(from questions: [LoadedQuestion]) -> ScopeCounts {
        let rwCount = questions.filter { $0.section == .readingAndWriting }.count
        let mathCount = questions.filter { $0.section == .math }.count

        var topicCounts: [String: Int] = [:]
        for question in questions {
            topicCounts[question.topic, default: 0] += 1
        }

        return ScopeCounts(
            total: questions.count,
            readingAndWriting: rwCount,
            math: mathCount,
            byTopic: topicCounts
        )
    }
}

// MARK: - Scope Counts
struct ScopeCounts {
    let total: Int
    let readingAndWriting: Int
    let math: Int
    let byTopic: [String: Int]

    func count(for section: SATSection) -> Int {
        switch section {
        case .readingAndWriting: return readingAndWriting
        case .math: return math
        }
    }

    func count(for topic: String) -> Int {
        byTopic[topic] ?? 0
    }
}
