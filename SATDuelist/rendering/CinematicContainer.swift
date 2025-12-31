import SwiftUI

// MARK: - Cinematic Container
// Wraps all gameplay and UI with post-processing effects
// Per Minigame.md: vignette (always on), bloom, motion blur, optional grain

struct CinematicContainer<Content: View>: View {
    let content: Content

    // Effect configuration
    var vignetteEnabled: Bool = true
    var bloomEnabled: Bool = true
    var motionBlurEnabled: Bool = false
    var grainEnabled: Bool = false
    var motionBlurIntensity: Double = 0.3

    init(
        vignette: Bool = true,
        bloom: Bool = true,
        motionBlur: Bool = false,
        grain: Bool = false,
        motionBlurIntensity: Double = 0.3,
        @ViewBuilder content: () -> Content
    ) {
        self.vignetteEnabled = vignette
        self.bloomEnabled = bloom
        self.motionBlurEnabled = motionBlur
        self.grainEnabled = grain
        self.motionBlurIntensity = motionBlurIntensity
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Primary background
            DesignSystem.Colors.primaryBackground
                .ignoresSafeArea()

            // Content
            content
        }
        .postProcessing(
            vignette: vignetteEnabled,
            bloom: bloomEnabled,
            motionBlur: motionBlurEnabled,
            grain: grainEnabled,
            motionBlurIntensity: motionBlurIntensity
        )
    }
}

// MARK: - Game Mode Cinematic Container Factory
// Pre-configured containers for specific game modes

/// Standard container for Duel Classic
func CinematicDuelClassic<Content: View>(@ViewBuilder content: () -> Content) -> CinematicContainer<Content> {
    CinematicContainer(
        vignette: true,
        bloom: true,
        motionBlur: false,
        grain: false,
        content: content
    )
}

/// High-speed container for Speed Rush (emphasizes motion blur)
func CinematicSpeedRush<Content: View>(@ViewBuilder content: () -> Content) -> CinematicContainer<Content> {
    CinematicContainer(
        vignette: true,
        bloom: true,
        motionBlur: true,
        grain: false,
        motionBlurIntensity: 0.5,
        content: content
    )
}

/// Tense container for Survival Mode
func CinematicSurvival<Content: View>(@ViewBuilder content: () -> Content) -> CinematicContainer<Content> {
    CinematicContainer(
        vignette: true,
        bloom: true,
        motionBlur: false,
        grain: true,
        content: content
    )
}

// MARK: - Animated Card Transition

struct CardTransition: ViewModifier {
    let isPresented: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isPresented ? 1 : 0)
            .offset(y: isPresented ? 0 : 30)
            .scaleEffect(isPresented ? 1 : 0.95)
    }
}

extension View {
    func cardTransition(isPresented: Bool) -> some View {
        modifier(CardTransition(isPresented: isPresented))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
    }
}

// MARK: - Shake Animation

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

extension View {
    func shake(trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

struct ShakeModifier: ViewModifier {
    let trigger: Int
    @State private var shakeCount: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: shakeCount))
            .onChange(of: trigger) { _, _ in
                withAnimation(.linear(duration: 0.4)) {
                    shakeCount += 1
                }
            }
    }
}

// MARK: - Scale Pop Animation

struct ScalePop: ViewModifier {
    let trigger: Int
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    scale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                }
            }
    }
}

extension View {
    func scalePop(trigger: Int) -> some View {
        modifier(ScalePop(trigger: trigger))
    }
}
