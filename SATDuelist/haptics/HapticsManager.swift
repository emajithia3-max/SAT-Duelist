import UIKit
import SwiftUI

// MARK: - Haptics Manager
// Per Minigame.md haptics specification

final class HapticsManager {
    static let shared = HapticsManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        // Prepare generators for minimal latency
        prepareAll()
    }

    // MARK: - Prepare

    func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    // MARK: - Game Events (per Minigame.md)

    /// Answer tap - Light impact
    func answerTap() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Correct answer - Success notification + medium impact
    func correctAnswer() {
        notificationGenerator.notificationOccurred(.success)
        mediumImpact.impactOccurred()
        notificationGenerator.prepare()
        mediumImpact.prepare()
    }

    /// Incorrect answer - Error notification + heavy impact
    func incorrectAnswer() {
        notificationGenerator.notificationOccurred(.error)
        heavyImpact.impactOccurred()
        notificationGenerator.prepare()
        heavyImpact.prepare()
    }

    /// Timer warning - Warning notification
    func timerWarning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    /// Game start/end - Subtle impact
    func gameTransition() {
        mediumImpact.impactOccurred(intensity: 0.6)
        mediumImpact.prepare()
    }

    /// Streak increment - Light double tap
    func streakIncrement() {
        lightImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.lightImpact.impactOccurred()
            self?.lightImpact.prepare()
        }
    }

    /// Streak lost - Heavy impact
    func streakLost() {
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }

    /// Selection change
    func selectionChanged() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    /// Button press
    func buttonPress() {
        lightImpact.impactOccurred(intensity: 0.8)
        lightImpact.prepare()
    }

    /// XP gained - Success with medium intensity
    func xpGained() {
        mediumImpact.impactOccurred(intensity: 0.7)
        mediumImpact.prepare()
    }
}

// MARK: - SwiftUI View Modifier

struct HapticFeedback: ViewModifier {
    enum FeedbackType {
        case tap
        case correct
        case incorrect
        case warning
        case selection
        case button
    }

    let type: FeedbackType
    let trigger: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    performHaptic()
                }
            }
    }

    private func performHaptic() {
        switch type {
        case .tap:
            HapticsManager.shared.answerTap()
        case .correct:
            HapticsManager.shared.correctAnswer()
        case .incorrect:
            HapticsManager.shared.incorrectAnswer()
        case .warning:
            HapticsManager.shared.timerWarning()
        case .selection:
            HapticsManager.shared.selectionChanged()
        case .button:
            HapticsManager.shared.buttonPress()
        }
    }
}

extension View {
    func hapticFeedback(_ type: HapticFeedback.FeedbackType, trigger: Bool) -> some View {
        modifier(HapticFeedback(type: type, trigger: trigger))
    }
}
