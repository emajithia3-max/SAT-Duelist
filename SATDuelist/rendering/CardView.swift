import SwiftUI

// MARK: - Card View
// Core visual unit per UI spec
// Corner radius: 18-22, Padding: 16-20, soft elevation

struct CardView<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 18
    var showGlow: Bool = true

    init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 18,
        showGlow: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.showGlow = showGlow
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
            // Soft elevation shadow per spec
            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
            // Glow if enabled
            .modifier(ConditionalGlow(showGlow: showGlow))
    }
}

// MARK: - Conditional Glow Modifier

private struct ConditionalGlow: ViewModifier {
    let showGlow: Bool

    func body(content: Content) -> some View {
        if showGlow {
            content.primaryGlow()
        } else {
            content
        }
    }
}

// MARK: - Question Card View

struct QuestionCardView: View {
    let question: LoadedQuestion
    var showDifficulty: Bool = true

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                // Section and Topic
                HStack {
                    Text(question.section.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textMuted)

                    Text("•")
                        .foregroundColor(DesignSystem.Colors.textMuted)

                    Text(question.topic)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    if showDifficulty {
                        DifficultyBadge(difficulty: question.question.difficulty)
                    }
                }

                // Question Text
                Text(question.question.question)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: Difficulty

    var body: some View {
        Text(difficulty.displayName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(hex: difficulty.color))
            )
    }
}

// MARK: - Answer Button

struct AnswerButton: View {
    let answer: String
    let isSelected: Bool
    let isCorrect: Bool?
    let isDisabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            if !isDisabled {
                action()
            }
        }) {
            HStack {
                Text(answer)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(AnswerButtonStyle(isDisabled: isDisabled))
        .disabled(isDisabled)
    }

    private var backgroundColor: Color {
        if let correct = isCorrect {
            if correct {
                return Color(hex: "#7C6CFF").opacity(0.15)
            } else if isSelected {
                return Color(hex: "#FF5D5D").opacity(0.15)
            }
        }
        return DesignSystem.Colors.elevated
    }

    private var borderColor: Color {
        if let correct = isCorrect {
            if correct {
                return Color(hex: "#7C6CFF")
            } else if isSelected {
                return Color(hex: "#FF5D5D")
            }
        }
        return isSelected ? Color(hex: "#7C6CFF") : DesignSystem.Colors.cardBorder
    }

    private var textColor: Color {
        if isDisabled && isCorrect == nil {
            return DesignSystem.Colors.textDisabled
        }
        return DesignSystem.Colors.textPrimary
    }
}

// MARK: - Answer Button Style

struct AnswerButtonStyle: ButtonStyle {
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !isDisabled ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - SPR Input Field

struct SPRInputField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .keyboardType(.numbersAndPunctuation)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color(hex: "#7C6CFF"))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Streak Counter

struct StreakCounter: View {
    let streak: Int
    let animate: Bool

    @State private var scale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 4) {
            Text("🔥")
                .font(.system(size: 20))

            Text("\(streak)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "#FF9F43"))
        }
        .scaleEffect(scale)
        .onChange(of: streak) { _, _ in
            if animate {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    scale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                }
            }
        }
    }
}

// MARK: - XP Counter

struct XPCounter: View {
    let xp: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#7C6CFF"))

            Text("\(xp) XP")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#7C6CFF"))
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(hex: "#2A2F44"))
                    .frame(height: height)

                // Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(0, geometry.size.width * CGFloat(progress)), height: height)
                    .animation(.easeOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: height)
    }
}
