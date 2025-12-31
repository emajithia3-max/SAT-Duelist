import SwiftUI

// MARK: - Game Selection View
// Entry point for choosing a minigame

struct GameSelectionView: View {
    @State private var selectedGame: GameMode?
    @State private var showScopeSelection = false

    var body: some View {
        NavigationStack {
            CinematicContainer {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Game mode cards
                        VStack(spacing: 16) {
                            GameModeCard(
                                mode: .duelClassic,
                                isSelected: selectedGame == .duelClassic
                            ) {
                                selectGame(.duelClassic)
                            }

                            GameModeCard(
                                mode: .speedRush,
                                isSelected: selectedGame == .speedRush
                            ) {
                                selectGame(.speedRush)
                            }

                            GameModeCard(
                                mode: .survival,
                                isSelected: selectedGame == .survival
                            ) {
                                selectGame(.survival)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Quick stats section
                        quickStatsSection

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showScopeSelection) {
                if let game = selectedGame {
                    ScopeSelectionView(gameMode: game)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("SAT Duelist")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Choose your battle")
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Quick Stats Section

    private var quickStatsSection: some View {
        VStack(spacing: 16) {
            Text("Today's Progress")
                .font(DesignSystem.Typography.cardTitle())
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                QuickStatCard(
                    icon: "flame.fill",
                    value: "0",
                    label: "Day Streak",
                    color: DesignSystem.Colors.orange
                )

                QuickStatCard(
                    icon: "star.fill",
                    value: "0",
                    label: "XP Today",
                    color: DesignSystem.Colors.primary
                )

                QuickStatCard(
                    icon: "checkmark.circle.fill",
                    value: "0",
                    label: "Questions",
                    color: DesignSystem.Colors.cyan
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Actions

    private func selectGame(_ mode: GameMode) {
        HapticsManager.shared.buttonPress()
        selectedGame = mode
        showScopeSelection = true
    }
}

// MARK: - Game Mode Enum

enum GameMode: String, CaseIterable, Identifiable {
    case duelClassic = "Duel Classic"
    case speedRush = "Speed Rush"
    case survival = "Survival"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .duelClassic: return "bolt.fill"
        case .speedRush: return "timer"
        case .survival: return "heart.fill"
        }
    }

    var description: String {
        switch self {
        case .duelClassic:
            return "Answer questions, build streaks, earn XP"
        case .speedRush:
            return "Race against the clock - how many can you answer?"
        case .survival:
            return "One wrong answer ends it all. How far can you go?"
        }
    }

    var color: Color {
        switch self {
        case .duelClassic: return Color(hex: "#7C6CFF")
        case .speedRush: return Color(hex: "#4DA3FF")
        case .survival: return Color(hex: "#FF5D5D")
        }
    }
}

// MARK: - Game Mode Card

struct GameModeCard: View {
    let mode: GameMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(mode.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: mode.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(mode.color)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(DesignSystem.Typography.cardTitle())
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(mode.description)
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .lineLimit(2)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? mode.color : DesignSystem.Colors.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
            .glow(color: mode.color, radius: 12, opacity: 0.1)
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
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
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }
}

#Preview {
    GameSelectionView()
}
