import SwiftUI

// MARK: - Post-Processing Pipeline
// Shared effects per Minigame.md: vignette, bloom, motion blur, optional grain

struct PostProcessingPipeline: ViewModifier {
    let enableVignette: Bool
    let enableBloom: Bool
    let enableMotionBlur: Bool
    let enableGrain: Bool
    let motionBlurIntensity: Double

    init(
        vignette: Bool = true,
        bloom: Bool = true,
        motionBlur: Bool = false,
        grain: Bool = false,
        motionBlurIntensity: Double = 0.3
    ) {
        self.enableVignette = vignette
        self.enableBloom = bloom
        self.enableMotionBlur = motionBlur
        self.enableGrain = grain
        self.motionBlurIntensity = motionBlurIntensity
    }

    func body(content: Content) -> some View {
        content
            // Motion blur effect
            .modifier(MotionBlurModifier(isActive: enableMotionBlur, intensity: motionBlurIntensity))
            // Vignette overlay
            .overlay(
                VignetteOverlay()
                    .opacity(enableVignette ? 1 : 0)
                    .allowsHitTesting(false)
            )
            // Film grain overlay
            .overlay(
                FilmGrainOverlay()
                    .opacity(enableGrain ? 0.03 : 0)
                    .allowsHitTesting(false)
            )
    }
}

// MARK: - Vignette Overlay

struct VignetteOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            RadialGradient(
                gradient: Gradient(colors: [
                    .clear,
                    .clear,
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.25),
                    Color.black.opacity(0.4)
                ]),
                center: .center,
                startRadius: min(geometry.size.width, geometry.size.height) * 0.3,
                endRadius: max(geometry.size.width, geometry.size.height) * 0.8
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Motion Blur Modifier

struct MotionBlurModifier: ViewModifier {
    let isActive: Bool
    let intensity: Double

    @State private var blurAmount: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .blur(radius: blurAmount)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeIn(duration: 0.1)) {
                        blurAmount = CGFloat(intensity * 8)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            blurAmount = 0
                        }
                    }
                }
            }
    }
}

// MARK: - Film Grain Overlay

struct FilmGrainOverlay: View {
    @State private var noiseOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Generate noise pattern
                for _ in 0..<Int(size.width * size.height * 0.001) {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let brightness = CGFloat.random(in: 0...1)

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(Color.white.opacity(Double(brightness) * 0.5))
                    )
                }
            }
        }
        .ignoresSafeArea()
        .blendMode(.overlay)
    }
}

// MARK: - View Extension

extension View {
    func postProcessing(
        vignette: Bool = true,
        bloom: Bool = true,
        motionBlur: Bool = false,
        grain: Bool = false,
        motionBlurIntensity: Double = 0.3
    ) -> some View {
        modifier(PostProcessingPipeline(
            vignette: vignette,
            bloom: bloom,
            motionBlur: motionBlur,
            grain: grain,
            motionBlurIntensity: motionBlurIntensity
        ))
    }
}
