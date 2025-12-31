import SwiftUI

// MARK: - Scope Selection View
// Choose: Anything Goes, English, or Math

struct ScopeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = QuestionEngine()

    let gameMode: GameMode

    @State private var selectedScope: ScopeOption = .anythingGoes
    @State private var showTopicPicker = false
    @State private var showGame = false
    @State private var selectedSection: SATSection?
    @State private var selectedTopic: String?
    @State private var scopeCounts: ScopeCounts?

    var body: some View {
        NavigationStack {
            CinematicContainer {
                VStack(spacing: 0) {
                    // Header
                    headerSection

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Scope options
                            VStack(spacing: 12) {
                                ScopeOptionCard(
                                    option: .anythingGoes,
                                    isSelected: selectedScope == .anythingGoes,
                                    questionCount: scopeCounts?.total ?? 0
                                ) {
                                    selectScope(.anythingGoes)
                                }

                                ScopeOptionCard(
                                    option: .english,
                                    isSelected: selectedScope == .english,
                                    questionCount: scopeCounts?.readingAndWriting ?? 0
                                ) {
                                    selectScope(.english)
                                }

                                ScopeOptionCard(
                                    option: .math,
                                    isSelected: selectedScope == .math,
                                    questionCount: scopeCounts?.math ?? 0
                                ) {
                                    selectScope(.math)
                                }
                            }
                            .padding(.horizontal, 20)

                            // Topic picker option
                            if selectedScope == .english || selectedScope == .math {
                                topicPickerButton
                                    .padding(.horizontal, 20)
                            }

                            Spacer(minLength: 100)
                        }
                        .padding(.top, 20)
                    }

                    // Start button
                    startButton
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadQuestions()
            }
            .fullScreenCover(isPresented: $showTopicPicker) {
                if let section = sectionForScope() {
                    TopicPickerView(
                        section: section,
                        topics: engine.getTopics(for: section),
                        selectedTopic: $selectedTopic
                    )
                }
            }
            .fullScreenCover(isPresented: $showGame) {
                gameView
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

            VStack(spacing: 4) {
                Text(gameMode.rawValue)
                    .font(DesignSystem.Typography.screenTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Select your scope")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }

            Spacer()

            // Spacer for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Topic Picker Button

    private var topicPickerButton: some View {
        Button {
            HapticsManager.shared.buttonPress()
            showTopicPicker = true
        } label: {
            HStack {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pick Specific Topic")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    if let topic = selectedTopic {
                        Text(topic)
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.primary)
                    } else {
                        Text("Optional - practice a specific area")
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedTopic != nil ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        VStack(spacing: 0) {
            Divider()
                .background(DesignSystem.Colors.cardBorder)

            PrimaryButton(title: "Start \(gameMode.rawValue)") {
                startGame()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(DesignSystem.Colors.primaryBackground)
    }

    // MARK: - Game View

    @ViewBuilder
    private var gameView: some View {
        let scope = buildScope()
        let config = buildConfig()

        switch gameMode {
        case .duelClassic:
            DuelClassicGame(scope: scope, config: config)
        case .speedRush:
            SpeedRushGame(scope: scope, config: config)
        case .survival:
            SurvivalModeGame(scope: scope, config: config)
        }
    }

    // MARK: - Actions

    private func loadQuestions() async {
        await engine.loadQuestions()
        scopeCounts = engine.getScopeCounts()
    }

    private func selectScope(_ option: ScopeOption) {
        HapticsManager.shared.selectionChanged()
        withAnimation(DesignSystem.Animation.quick) {
            selectedScope = option
            // Clear topic when switching scope
            if option == .anythingGoes {
                selectedTopic = nil
            }
        }
    }

    private func sectionForScope() -> SATSection? {
        switch selectedScope {
        case .anythingGoes: return nil
        case .english: return .readingAndWriting
        case .math: return .math
        }
    }

    private func buildScope() -> ScopeSelection {
        switch selectedScope {
        case .anythingGoes:
            return .all
        case .english:
            if let topic = selectedTopic {
                return .topicSpecific(section: .readingAndWriting, topic: topic)
            }
            return .sectionOnly(.readingAndWriting)
        case .math:
            if let topic = selectedTopic {
                return .topicSpecific(section: .math, topic: topic)
            }
            return .sectionOnly(.math)
        }
    }

    private func buildConfig() -> SessionConfig {
        switch gameMode {
        case .duelClassic:
            return .default
        case .speedRush:
            return .timed(60)
        case .survival:
            return .default
        }
    }

    private func startGame() {
        HapticsManager.shared.gameTransition()
        showGame = true
    }
}

// MARK: - Scope Option Enum

enum ScopeOption: String, CaseIterable {
    case anythingGoes = "Anything Goes"
    case english = "English"
    case math = "Math"

    var icon: String {
        switch self {
        case .anythingGoes: return "infinity"
        case .english: return "text.book.closed.fill"
        case .math: return "function"
        }
    }

    var description: String {
        switch self {
        case .anythingGoes: return "All sections and topics"
        case .english: return "Reading and Writing"
        case .math: return "Math questions only"
        }
    }

    var color: Color {
        switch self {
        case .anythingGoes: return Color(hex: "#7C6CFF")
        case .english: return Color(hex: "#4DA3FF")
        case .math: return Color(hex: "#3FE0C5")
        }
    }
}

// MARK: - Scope Option Card

struct ScopeOptionCard: View {
    let option: ScopeOption
    let isSelected: Bool
    let questionCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(option.color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: option.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(option.color)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.rawValue)
                        .font(DesignSystem.Typography.cardTitle())
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(questionCount) questions")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textMuted)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? option.color : DesignSystem.Colors.cardBorder, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(option.color)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? option.color : DesignSystem.Colors.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(CardButtonStyle())
    }
}

#Preview {
    ScopeSelectionView(gameMode: .duelClassic)
}
