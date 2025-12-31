import SwiftUI

// MARK: - Profile View
// User stats and achievements (placeholder for future implementation)

struct ProfileView: View {
    // Mock user data - will be replaced with real data from GameSettingsManager
    @ObservedObject private var settings = GameSettingsManager.shared

    private let currentLevel = 12
    private let maxStreak = 23
    private let dayStreak = 7

    var body: some View {
        ZStack {
            DesignSystem.Colors.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Profile header
                        profileHeaderSection

                        // Stats grid
                        statsGridSection

                        // Streak section
                        streakSection

                        // Achievement section
                        achievementsSection

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Text("Profile")
            .font(DesignSystem.Typography.screenTitle())
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }

    // MARK: - Profile Header

    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient.primaryButton
                    )
                    .frame(width: 80, height: 80)

                Text("🎯")
                    .font(.system(size: 40))
            }

            // Level badge
            HStack(spacing: 8) {
                Text("Level \(currentLevel)")
                    .font(DesignSystem.Typography.cardTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("•")
                    .foregroundColor(DesignSystem.Colors.textMuted)

                Text("\(settings.totalScore) XP")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.primary)
            }

            // XP progress to next level
            VStack(spacing: 8) {
                ProgressBar(
                    progress: Double(settings.totalScore % 1000) / 1000.0,
                    color: DesignSystem.Colors.primary
                )
                .frame(width: 200)

                Text("\(settings.totalScore % 1000) / 1000 XP to Level \(currentLevel + 1)")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGridSection: some View {
        CardView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ProfileStatItem(
                    icon: "checkmark.circle.fill",
                    value: "\(settings.questionsAnswered)",
                    label: "Questions",
                    color: DesignSystem.Colors.cyan
                )

                ProfileStatItem(
                    icon: "percent",
                    value: String(format: "%.1f%%", settings.accuracy),
                    label: "Accuracy",
                    color: DesignSystem.Colors.blue
                )

                ProfileStatItem(
                    icon: "flame.fill",
                    value: "\(maxStreak)",
                    label: "Best Streak",
                    color: DesignSystem.Colors.orange
                )

                ProfileStatItem(
                    icon: "star.fill",
                    value: "\(settings.totalScore)",
                    label: "Total XP",
                    color: DesignSystem.Colors.primary
                )
            }
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        CardView {
            VStack(spacing: 16) {
                HStack {
                    Text("🔥")
                        .font(.system(size: 32))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(dayStreak) Day Streak")
                            .font(DesignSystem.Typography.cardTitle())
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Keep it going!")
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }

                    Spacer()
                }

                // Day dots
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { day in
                        DayDot(
                            day: ["S", "M", "T", "W", "T", "F", "S"][day],
                            isCompleted: day < dayStreak,
                            isToday: day == dayStreak - 1
                        )
                    }
                }
            }
        }
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(DesignSystem.Typography.cardTitle())
                .foregroundColor(DesignSystem.Colors.textSecondary)

            CardView {
                VStack(spacing: 12) {
                    AchievementRow(
                        icon: "star.fill",
                        title: "First Steps",
                        description: "Answer your first question",
                        isUnlocked: true
                    )

                    Divider()
                        .background(DesignSystem.Colors.cardBorder)

                    AchievementRow(
                        icon: "flame.fill",
                        title: "On Fire",
                        description: "Get a 10 question streak",
                        isUnlocked: true
                    )

                    Divider()
                        .background(DesignSystem.Colors.cardBorder)

                    AchievementRow(
                        icon: "crown.fill",
                        title: "SAT Master",
                        description: "Reach Level 50",
                        isUnlocked: false
                    )
                }
            }
        }
    }
}

// MARK: - Profile Stat Item

struct ProfileStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
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

// MARK: - Day Dot

struct DayDot: View {
    let day: String
    let isCompleted: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(isCompleted ? DesignSystem.Colors.primary : Color(hex: "#2A2F44"))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(isToday ? DesignSystem.Colors.primary : .clear, lineWidth: 2)
                        .padding(-3)
                )

            Text(day)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
    }
}

// MARK: - Achievement Row

struct AchievementRow: View {
    let icon: String
    let title: String
    let description: String
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? DesignSystem.Colors.primary.opacity(0.15) : DesignSystem.Colors.elevated)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isUnlocked ? DesignSystem.Colors.primary : DesignSystem.Colors.textDisabled)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(isUnlocked ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textMuted)

                Text(description)
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }

            Spacer()

            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DesignSystem.Colors.cyan)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.textDisabled)
            }
        }
    }
}

#Preview {
    ProfileView()
}
