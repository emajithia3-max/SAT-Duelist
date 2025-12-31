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

                        // Study Mode Games
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Study Modes")
                                .font(DesignSystem.Typography.cardTitle())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 12) {
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
                        }

                        // Arcade Games section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Arcade Games")
                                    .font(DesignSystem.Typography.cardTitle())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)

                                Text("12 GAMES!")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(DesignSystem.Colors.orange)
                                    )
                            }
                            .padding(.horizontal, 20)

                            VStack(spacing: 12) {
                                ForEach(GameMode.allCases.filter { $0.isArcadeGame }, id: \.id) { mode in
                                    GameModeCard(
                                        mode: mode,
                                        isSelected: selectedGame == mode
                                    ) {
                                        selectGame(mode)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

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
    case meteorDefense = "Meteor Defense"
    case towerClimb = "Tower Climb"
    case snakeFeast = "Snake Feast"
    case breakoutBlitz = "Breakout Blitz"
    case flappyScholar = "Flappy Scholar"
    case asteroidDodge = "Asteroid Dodge"
    case fruitSlice = "Fruit Slice"
    case gravityRunner = "Gravity Runner"
    case bubblePop = "Bubble Pop"
    case pinballWizard = "Pinball Wizard"
    case laserMaze = "Laser Maze"
    case rhythmBlaster = "Rhythm Blaster"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .duelClassic: return "bolt.fill"
        case .speedRush: return "timer"
        case .survival: return "heart.fill"
        case .meteorDefense: return "sparkles"
        case .towerClimb: return "arrow.up.circle.fill"
        case .snakeFeast: return "circle.grid.3x3.fill"
        case .breakoutBlitz: return "rectangle.3.group.fill"
        case .flappyScholar: return "bird.fill"
        case .asteroidDodge: return "staroflife.fill"
        case .fruitSlice: return "scissors"
        case .gravityRunner: return "figure.run"
        case .bubblePop: return "bubble.left.and.bubble.right.fill"
        case .pinballWizard: return "circle.circle.fill"
        case .laserMaze: return "laser.burst"
        case .rhythmBlaster: return "music.note.list"
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
        case .meteorDefense:
            return "Blast meteors by answering questions - defend your ship!"
        case .towerClimb:
            return "Climb the tower! Jump up with each correct answer"
        case .snakeFeast:
            return "Classic snake - eat correct answers to grow!"
        case .breakoutBlitz:
            return "Brick breaker madness - hit the right answer!"
        case .flappyScholar:
            return "Tap to fly through the correct answer gates!"
        case .asteroidDodge:
            return "Dodge asteroids, answer for power-ups!"
        case .fruitSlice:
            return "Slice the correct answers ninja style!"
        case .gravityRunner:
            return "Run and flip gravity - answer to unlock!"
        case .bubblePop:
            return "Pop the bubbles with correct answers!"
        case .pinballWizard:
            return "Pinball action - hit answer bumpers!"
        case .laserMaze:
            return "Navigate lasers, solve to open gates!"
        case .rhythmBlaster:
            return "Rhythm game - tap answers to the beat!"
        }
    }

    var color: Color {
        switch self {
        case .duelClassic: return Color(hex: "#7C6CFF")
        case .speedRush: return Color(hex: "#4DA3FF")
        case .survival: return Color(hex: "#FF5D5D")
        case .meteorDefense: return Color(hex: "#FF9F43")
        case .towerClimb: return Color(hex: "#3FE0C5")
        case .snakeFeast: return Color(hex: "#51CF66")
        case .breakoutBlitz: return Color(hex: "#FF6B6B")
        case .flappyScholar: return Color(hex: "#FFE66D")
        case .asteroidDodge: return Color(hex: "#845EC2")
        case .fruitSlice: return Color(hex: "#FF6F91")
        case .gravityRunner: return Color(hex: "#00C9A7")
        case .bubblePop: return Color(hex: "#4ECDC4")
        case .pinballWizard: return Color(hex: "#C34A36")
        case .laserMaze: return Color(hex: "#FF4757")
        case .rhythmBlaster: return Color(hex: "#A855F7")
        }
    }

    var isArcadeGame: Bool {
        switch self {
        case .duelClassic, .speedRush, .survival:
            return false
        default:
            return true
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
