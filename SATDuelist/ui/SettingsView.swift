import SwiftUI

// MARK: - Settings View
// Manage hidden games and app preferences

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = GameSettingsManager.shared
    @State private var showResetConfirmation = false

    var body: some View {
        CinematicContainer {
            VStack(spacing: 0) {
                // Header
                headerSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hidden games section
                        hiddenGamesSection

                        // App info section
                        appInfoSection

                        // Reset section
                        resetSection

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                }
            }
        }
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will reset all your stats, hidden games, and preferences. This cannot be undone.")
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

            Text("Settings")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Hidden Games Section

    private var hiddenGamesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Hidden Games")
                    .font(DesignSystem.Typography.cardTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if !settings.hiddenGames.isEmpty {
                    Text("\(settings.hiddenGames.count) hidden")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textMuted)
                }
            }

            if settings.hiddenGames.isEmpty {
                // No hidden games
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.cyan)

                    Text("All games are visible in random selection")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textMuted)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            } else {
                // List of hidden games
                VStack(spacing: 12) {
                    ForEach(Array(settings.hiddenGames).sorted(), id: \.self) { gameId in
                        if let game = GameMode.allCases.first(where: { $0.id == gameId }) {
                            HiddenGameRow(game: game) {
                                withAnimation {
                                    settings.unhideGame(gameId)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(DesignSystem.Typography.cardTitle())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            VStack(spacing: 0) {
                InfoRow(label: "Version", value: "1.0.0")
                Divider()
                    .background(DesignSystem.Colors.cardBorder)
                InfoRow(label: "Total Games", value: "\(GameMode.allCases.filter { $0.isArcadeGame }.count)")
                Divider()
                    .background(DesignSystem.Colors.cardBorder)
                InfoRow(label: "Question Bank", value: "SAT 2026")
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data")
                .font(DesignSystem.Typography.cardTitle())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Button {
                showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(DesignSystem.Colors.red)

                    Text("Reset All Data")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.red)

                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
    }

    // MARK: - Actions

    private func resetAllData() {
        // Reset hidden games
        settings.hiddenGames.removeAll()

        // Reset stats
        UserDefaults.standard.removeObject(forKey: "gamesPlayed")
        UserDefaults.standard.removeObject(forKey: "totalScore")
        UserDefaults.standard.removeObject(forKey: "questionsAnswered")
        UserDefaults.standard.removeObject(forKey: "correctAnswers")
        UserDefaults.standard.removeObject(forKey: "recentlyPlayedGames")

        HapticsManager.shared.buttonPress()
    }
}

// MARK: - Hidden Game Row

struct HiddenGameRow: View {
    let game: GameMode
    let onUnhide: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(game.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: game.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(game.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(game.rawValue)
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Hidden from random selection")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }

            Spacer()

            Button {
                HapticsManager.shared.buttonPress()
                onUnhide()
            } label: {
                Text("Unhide")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.cyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.cyan.opacity(0.15))
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(16)
    }
}

#Preview {
    SettingsView()
}
