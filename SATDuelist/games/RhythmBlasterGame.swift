import SwiftUI

// MARK: - Rhythm Blaster Game
// Guitar Hero style - tap answers in rhythm as they scroll down!

struct RhythmBlasterGame: View {
    @StateObject private var engine = QuestionEngine()
    @Environment(\.dismiss) private var dismiss

    let scope: ScopeSelection
    let config: SessionConfig

    // Game state
    @State private var notes: [RhythmNote] = []
    @State private var currentQuestion: LoadedQuestion?
    @State private var score: Int = 0
    @State private var combo: Int = 0
    @State private var maxCombo: Int = 0
    @State private var multiplier: Int = 1
    @State private var gameEnded = false
    @State private var hitEffects: [NoteHitEffect] = []
    @State private var missCount: Int = 0
    @State private var perfectCount: Int = 0
    @State private var goodCount: Int = 0

    let laneCount = 4
    let hitLineY: CGFloat = 650
    let noteSpeed: CGFloat = 4
    let perfectWindow: CGFloat = 20
    let goodWindow: CGFloat = 40

    let gameLoop = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    let noteSpawner = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let laneWidth = (geometry.size.width - 40) / CGFloat(laneCount)

            CinematicContainer(vignette: true, bloom: true) {
                ZStack {
                    // Neon background
                    NeonBackgroundView()

                    // Lanes
                    HStack(spacing: 0) {
                        ForEach(0..<laneCount, id: \.self) { lane in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: laneWidth)
                                .overlay(
                                    Rectangle()
                                        .fill(laneColor(lane).opacity(0.1))
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(laneColor(lane).opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)

                    // Hit line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 4)
                        .position(x: geometry.size.width / 2, y: hitLineY)
                        .shadow(color: .white, radius: 10)

                    // Notes
                    ForEach(notes) { note in
                        NoteView(note: note, laneWidth: laneWidth, laneColor: laneColor(note.lane))
                            .position(
                                x: 20 + laneWidth / 2 + CGFloat(note.lane) * laneWidth,
                                y: note.y
                            )
                    }

                    // Hit effects
                    ForEach(hitEffects) { effect in
                        NoteHitEffectView(effect: effect, laneWidth: laneWidth)
                    }

                    // Lane tap buttons
                    HStack(spacing: 0) {
                        ForEach(0..<laneCount, id: \.self) { lane in
                            LaneTapButton(lane: lane, laneWidth: laneWidth, color: laneColor(lane)) {
                                tapLane(lane, geometry: geometry)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .position(x: geometry.size.width / 2, y: hitLineY)

                    // UI Overlay
                    VStack {
                        // Top bar
                        HStack {
                            comboDisplay
                            Spacer()
                            scoreDisplay
                            Spacer()
                            multiplierDisplay
                            Spacer()
                            closeButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)

                        // Question
                        if let question = currentQuestion {
                            Text(question.question.question)
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
                                )
                                .padding(.horizontal, 20)
                        }

                        Spacer()
                    }

                    // Game over
                    if gameEnded {
                        gameOverOverlay
                    }
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await startGame()
        }
        .onReceive(gameLoop) { _ in
            guard !gameEnded else { return }
            updateGame()
        }
        .onReceive(noteSpawner) { _ in
            guard !gameEnded else { return }
            spawnNotes()
        }
    }

    private func laneColor(_ lane: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "#FF6B6B"),
            Color(hex: "#4ECDC4"),
            Color(hex: "#FFE66D"),
            Color(hex: "#95E1D3")
        ]
        return colors[lane % colors.count]
    }

    // MARK: - Combo Display

    private var comboDisplay: some View {
        VStack(spacing: 2) {
            Text("\(combo)")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(combo > 10 ? DesignSystem.Colors.orange : DesignSystem.Colors.textPrimary)
            Text("COMBO")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Score Display

    private var scoreDisplay: some View {
        VStack(spacing: 2) {
            Text("\(score)")
                .font(DesignSystem.Typography.number())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text("SCORE")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
        )
    }

    // MARK: - Multiplier Display

    private var multiplierDisplay: some View {
        Text("\(multiplier)x")
            .font(.system(size: 18, weight: .black))
            .foregroundColor(multiplier > 1 ? DesignSystem.Colors.orange : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
            )
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            HapticsManager.shared.buttonPress()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.elevated.opacity(0.9))
                )
        }
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 24) {
            Text("SONG COMPLETE!")
                .font(DesignSystem.Typography.screenTitle())
                .foregroundColor(DesignSystem.Colors.cyan)

            // Grade
            Text(calculateGrade())
                .font(.system(size: 64, weight: .black))
                .foregroundColor(gradeColor())

            VStack(spacing: 16) {
                StatRow(icon: "star.fill", label: "Score", value: "\(score)", color: DesignSystem.Colors.orange)
                StatRow(icon: "flame.fill", label: "Max Combo", value: "\(maxCombo)", color: DesignSystem.Colors.red)
                HStack(spacing: 20) {
                    VStack {
                        Text("\(perfectCount)")
                            .font(DesignSystem.Typography.number())
                            .foregroundColor(DesignSystem.Colors.cyan)
                        Text("Perfect")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }
                    VStack {
                        Text("\(goodCount)")
                            .font(DesignSystem.Typography.number())
                            .foregroundColor(Color(hex: "#51CF66"))
                        Text("Good")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }
                    VStack {
                        Text("\(missCount)")
                            .font(DesignSystem.Typography.number())
                            .foregroundColor(DesignSystem.Colors.red)
                        Text("Miss")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            PrimaryButton(title: "Play Again") {
                resetGame()
            }

            Button { dismiss() } label: {
                Text("Exit")
                    .font(DesignSystem.Typography.button())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignSystem.Colors.primaryBackground.opacity(0.95))
        )
        .padding(20)
    }

    private func calculateGrade() -> String {
        let total = perfectCount + goodCount + missCount
        guard total > 0 else { return "?" }

        let accuracy = Double(perfectCount * 100 + goodCount * 50) / Double(total * 100)

        if accuracy >= 0.95 { return "S" }
        if accuracy >= 0.85 { return "A" }
        if accuracy >= 0.70 { return "B" }
        if accuracy >= 0.50 { return "C" }
        return "D"
    }

    private func gradeColor() -> Color {
        switch calculateGrade() {
        case "S": return DesignSystem.Colors.orange
        case "A": return DesignSystem.Colors.cyan
        case "B": return Color(hex: "#51CF66")
        case "C": return DesignSystem.Colors.primary
        default: return DesignSystem.Colors.red
        }
    }

    // MARK: - Game Logic

    private func startGame() async {
        await engine.loadQuestions()
        engine.configureSession(scope: scope, config: config)

        if let question = engine.startSession() {
            currentQuestion = question
        }
    }

    private func spawnNotes() {
        guard let question = currentQuestion else { return }

        let answers = question.question.allAnswers
        var availableLanes = Array(0..<laneCount)

        // Spawn notes for each answer
        for (index, answer) in answers.enumerated() {
            guard index < laneCount && !availableLanes.isEmpty else { break }

            let lane = availableLanes.removeFirst()
            let isCorrect = answer == question.question.correctAnswer

            let note = RhythmNote(
                id: UUID(),
                lane: lane,
                y: -50,
                answer: answer,
                isCorrect: isCorrect
            )
            notes.append(note)
        }
    }

    private func updateGame() {
        // Move notes
        for i in notes.indices.reversed() {
            notes[i].y += noteSpeed

            // Remove missed notes
            if notes[i].y > hitLineY + 100 {
                let note = notes[i]
                notes.remove(at: i)

                if note.isCorrect {
                    // Missed correct answer
                    missNote()
                }
            }
        }

        // Check if song complete (no more questions and no notes)
        if !engine.hasMoreQuestions && notes.isEmpty {
            endGame()
        }

        // Clean up effects
        hitEffects.removeAll { Date().timeIntervalSince($0.createdAt) > 0.5 }

        // Update multiplier based on combo
        multiplier = min(8, 1 + combo / 10)
    }

    private func tapLane(_ lane: Int, geometry: GeometryProxy) {
        // Find closest note in this lane near the hit line
        let laneWidth = (geometry.size.width - 40) / CGFloat(laneCount)
        let hitX = 20 + laneWidth / 2 + CGFloat(lane) * laneWidth

        if let noteIndex = notes.firstIndex(where: {
            $0.lane == lane && abs($0.y - hitLineY) < goodWindow
        }) {
            let note = notes[noteIndex]
            let distance = abs(note.y - hitLineY)

            if note.isCorrect {
                if distance <= perfectWindow {
                    hitPerfect(at: noteIndex, x: hitX)
                } else {
                    hitGood(at: noteIndex, x: hitX)
                }
                _ = engine.submitAnswer(note.answer)
                advanceQuestion()
            } else {
                hitWrong(at: noteIndex, x: hitX)
                _ = engine.submitAnswer(note.answer)
            }

            notes.remove(at: noteIndex)
        }
    }

    private func hitPerfect(at index: Int, x: CGFloat) {
        HapticsManager.shared.correctAnswer()
        perfectCount += 1
        combo += 1
        maxCombo = max(maxCombo, combo)
        score += 100 * multiplier

        let effect = NoteHitEffect(id: UUID(), x: x, y: hitLineY, type: .perfect, createdAt: Date())
        hitEffects.append(effect)
    }

    private func hitGood(at index: Int, x: CGFloat) {
        HapticsManager.shared.selectionChanged()
        goodCount += 1
        combo += 1
        maxCombo = max(maxCombo, combo)
        score += 50 * multiplier

        let effect = NoteHitEffect(id: UUID(), x: x, y: hitLineY, type: .good, createdAt: Date())
        hitEffects.append(effect)
    }

    private func hitWrong(at index: Int, x: CGFloat) {
        HapticsManager.shared.incorrectAnswer()
        missCount += 1
        combo = 0

        let effect = NoteHitEffect(id: UUID(), x: x, y: hitLineY, type: .miss, createdAt: Date())
        hitEffects.append(effect)
    }

    private func missNote() {
        missCount += 1
        combo = 0
        HapticsManager.shared.incorrectAnswer()
    }

    private func advanceQuestion() {
        if engine.hasMoreQuestions {
            currentQuestion = engine.nextQuestion()
        }
    }

    private func endGame() {
        gameEnded = true
        HapticsManager.shared.gameTransition()
    }

    private func resetGame() {
        gameEnded = false
        score = 0
        combo = 0
        maxCombo = 0
        multiplier = 1
        perfectCount = 0
        goodCount = 0
        missCount = 0
        notes.removeAll()
        hitEffects.removeAll()
        Task {
            await startGame()
        }
    }
}

// MARK: - Rhythm Note Model

struct RhythmNote: Identifiable {
    let id: UUID
    let lane: Int
    var y: CGFloat
    let answer: String
    let isCorrect: Bool
}

// MARK: - Note Hit Effect Model

struct NoteHitEffect: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let type: HitType
    let createdAt: Date

    enum HitType {
        case perfect, good, miss
    }
}

// MARK: - Note View

struct NoteView: View {
    let note: RhythmNote
    let laneWidth: CGFloat
    let laneColor: Color

    var body: some View {
        ZStack {
            // Note body
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [laneColor, laneColor.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: laneWidth - 10, height: 50)
                .shadow(color: laneColor, radius: 5)

            // Answer text
            Text(note.answer)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: laneWidth - 20)
        }
    }
}

// MARK: - Lane Tap Button

struct LaneTapButton: View {
    let lane: Int
    let laneWidth: CGFloat
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Rectangle()
            .fill(color.opacity(isPressed ? 0.5 : 0.2))
            .frame(width: laneWidth, height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 2)
                    .padding(5)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            action()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

// MARK: - Note Hit Effect View

struct NoteHitEffectView: View {
    let effect: NoteHitEffect
    let laneWidth: CGFloat

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    var body: some View {
        VStack(spacing: 4) {
            Text(effectText)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(effectColor)

            // Particle burst
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(effectColor)
                        .frame(width: 6, height: 6)
                        .offset(
                            x: cos(CGFloat(i) * .pi / 4) * 30 * scale,
                            y: sin(CGFloat(i) * .pi / 4) * 30 * scale
                        )
                }
            }
        }
        .opacity(opacity)
        .position(x: effect.x, y: effect.y - 30)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                scale = 2.0
                opacity = 0
            }
        }
    }

    private var effectText: String {
        switch effect.type {
        case .perfect: return "PERFECT!"
        case .good: return "GOOD!"
        case .miss: return "MISS"
        }
    }

    private var effectColor: Color {
        switch effect.type {
        case .perfect: return DesignSystem.Colors.cyan
        case .good: return Color(hex: "#51CF66")
        case .miss: return DesignSystem.Colors.red
        }
    }
}

// MARK: - Neon Background View

struct NeonBackgroundView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Dark base
            LinearGradient(
                colors: [Color(hex: "#0a0a15"), Color(hex: "#1a0a25")],
                startPoint: .top,
                endPoint: .bottom
            )

            // Neon strips
            GeometryReader { geometry in
                ForEach(0..<5, id: \.self) { i in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.1),
                                    DesignSystem.Colors.cyan.opacity(0.2),
                                    DesignSystem.Colors.primary.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: geometry.size.height)
                        .position(x: CGFloat(i + 1) * geometry.size.width / 6, y: geometry.size.height / 2)
                        .opacity(pulse ? 0.8 : 0.3)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
