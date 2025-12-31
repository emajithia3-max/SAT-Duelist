import SwiftUI

// MARK: - Leaderboard View
// Display rankings and scores (placeholder for future implementation)

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss

    // Mock data for now
    private let mockLeaderboard: [(rank: Int, name: String, score: Int, streak: Int)] = [
        (1, "ProPlayer123", 15420, 45),
        (2, "MathWhiz", 14850, 38),
        (3, "SATMaster", 13200, 42),
        (4, "StudyHero", 11890, 35),
        (5, "TestAce", 10540, 31),
        (6, "BrainStorm", 9870, 28),
        (7, "QuizKing", 8920, 25),
        (8, "LearnFast", 7650, 22),
        (9, "SmartCookie", 6480, 19),
        (10, "StudyBuddy", 5320, 16)
    ]

    var body: some View {
        CinematicContainer {
            VStack(spacing: 0) {
                // Header
                headerSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Top 3 podium
                        podiumSection

                        // Remaining rankings
                        VStack(spacing: 8) {
                            ForEach(mockLeaderboard.dropFirst(3), id: \.rank) { entry in
                                LeaderboardRow(
                                    rank: entry.rank,
                                    name: entry.name,
                                    score: entry.score,
                                    streak: entry.streak
                                )
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Button {
                HapticsManager.shared.buttonPress()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.elevated)
                    )
            }

            Spacer()

            Text("Leaderboard")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Podium Section

    private var podiumSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 2nd place
            if mockLeaderboard.count > 1 {
                PodiumCard(
                    rank: 2,
                    name: mockLeaderboard[1].name,
                    score: mockLeaderboard[1].score,
                    height: 100
                )
            }

            // 1st place
            if !mockLeaderboard.isEmpty {
                PodiumCard(
                    rank: 1,
                    name: mockLeaderboard[0].name,
                    score: mockLeaderboard[0].score,
                    height: 130
                )
            }

            // 3rd place
            if mockLeaderboard.count > 2 {
                PodiumCard(
                    rank: 3,
                    name: mockLeaderboard[2].name,
                    score: mockLeaderboard[2].score,
                    height: 80
                )
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Podium Card

struct PodiumCard: View {
    let rank: Int
    let name: String
    let score: Int
    let height: CGFloat

    private var medalColor: Color {
        switch rank {
        case 1: return Color(hex: "#FFD700")  // Gold
        case 2: return Color(hex: "#C0C0C0")  // Silver
        case 3: return Color(hex: "#CD7F32")  // Bronze
        default: return DesignSystem.Colors.textMuted
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Medal
            ZStack {
                Circle()
                    .fill(medalColor)
                    .frame(width: 40, height: 40)

                Text("\(rank)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            // Name
            Text(name)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(1)

            // Score
            Text("\(score)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(medalColor)

            // Podium base
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignSystem.Colors.cardBackground)
                .frame(height: height)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let name: String
    let score: Int
    let streak: Int

    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("#\(rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textMuted)
                .frame(width: 36)

            // Name
            Text(name)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            // Streak
            HStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 14))
                Text("\(streak)")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.orange)
            }

            // Score
            Text("\(score)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }
}

#Preview {
    LeaderboardView()
}
