import SwiftUI

// MARK: - Session Summary View
// Standalone view for session results

struct SessionSummaryView: View {
    @Environment(\.dismiss) private var dismiss

    let result: SessionResult
    let gameMode: GameMode

    var body: some View {
        CinematicContainer {
            VStack(spacing: 0) {
                Spacer()

                // Result card
                resultCard

                Spacer()

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Result Card

    private var resultCard: some View {
        CardView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    // Performance emoji
                    Text(performanceEmoji)
                        .font(.system(size: 60))

                    Text(performanceTitle)
                        .font(DesignSystem.Typography.screenTitle())
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(gameMode.rawValue) Complete")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textMuted)
                }

                // Stats
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(result.correctCount)")
                            .font(DesignSystem.Typography.number())
                            .foregroundColor(DesignSystem.Colors.cyan)

                        Text("Correct")
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }

                    Rectangle()
                        .fill(DesignSystem.Colors.cardBorder)
                        .frame(width: 1, height: 40)

                    VStack(spacing: 4) {
                        Text("\(Int(result.accuracy * 100))%")
                            .font(DesignSystem.Typography.number())
                            .foregroundColor(DesignSystem.Colors.blue)

                        Text("Accuracy")
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }

                    Rectangle()
                        .fill(DesignSystem.Colors.cardBorder)
                        .frame(width: 1, height: 40)

                    VStack(spacing: 4) {
                        Text("\(result.maxStreak)")
                            .font(DesignSystem.Typography.number())
                            .foregroundColor(DesignSystem.Colors.orange)

                        Text("Streak")
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }
                }

                Divider()
                    .background(DesignSystem.Colors.cardBorder)

                // XP earned
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("+\(result.xpEarned) XP")
                            .font(DesignSystem.Typography.number())
                            .foregroundColor(DesignSystem.Colors.primary)

                        Text("Experience earned")
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }

                    Spacer()
                }

                // Time
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textMuted)

                    Text("Time: \(formatTime(result.timeSpent))")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textMuted)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Play Again") {
                // Would navigate back to scope selection
                dismiss()
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(DesignSystem.Typography.button())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
        }
    }

    // MARK: - Helpers

    private var performanceEmoji: String {
        let accuracy = result.accuracy
        switch accuracy {
        case 0.9...: return "🏆"
        case 0.75..<0.9: return "🌟"
        case 0.5..<0.75: return "💪"
        default: return "📚"
        }
    }

    private var performanceTitle: String {
        let accuracy = result.accuracy
        switch accuracy {
        case 0.9...: return "Outstanding!"
        case 0.75..<0.9: return "Great Job!"
        case 0.5..<0.75: return "Good Effort!"
        default: return "Keep Practicing!"
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    SessionSummaryView(
        result: SessionResult(
            totalAnswered: 15,
            correctCount: 12,
            accuracy: 0.8,
            maxStreak: 7,
            timeSpent: 180,
            perTopicBreakdown: nil,
            missedSkills: nil
        ),
        gameMode: .duelClassic
    )
}
