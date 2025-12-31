import SwiftUI

// MARK: - Glow Modifier
// Applies purple glow effect per UI spec

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let opacity: Double

    init(
        color: Color = Color(hex: "#7C6CFF"),
        radius: CGFloat = 12,
        opacity: Double = 0.15
    ) {
        self.color = color
        self.radius = radius
        self.opacity = opacity
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(opacity * 0.5), radius: radius * 0.5, x: 0, y: 0)
    }
}

// MARK: - Pulse Glow Modifier
// Animated glow for correct answers

struct PulseGlowModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    @State private var glowOpacity: Double = 0.15

    init(isActive: Bool, color: Color = Color(hex: "#7C6CFF")) {
        self.isActive = isActive
        self.color = color
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isActive ? glowOpacity : 0.15), radius: 12, x: 0, y: 0)
            .shadow(color: color.opacity(isActive ? glowOpacity * 0.5 : 0.075), radius: 6, x: 0, y: 0)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.3).repeatCount(2, autoreverses: true)) {
                        glowOpacity = 0.4
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            glowOpacity = 0.15
                        }
                    }
                }
            }
    }
}

// MARK: - Error Flash Modifier
// Red flash for incorrect answers

struct ErrorFlashModifier: ViewModifier {
    let isActive: Bool
    @State private var showFlash = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#FF5D5D").opacity(showFlash ? 0.3 : 0))
                    .allowsHitTesting(false)
            )
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeIn(duration: 0.1)) {
                        showFlash = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showFlash = false
                        }
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func glow(
        color: Color = Color(hex: "#7C6CFF"),
        radius: CGFloat = 12,
        opacity: Double = 0.15
    ) -> some View {
        modifier(GlowModifier(color: color, radius: radius, opacity: opacity))
    }

    func pulseGlow(isActive: Bool, color: Color = Color(hex: "#7C6CFF")) -> some View {
        modifier(PulseGlowModifier(isActive: isActive, color: color))
    }

    func errorFlash(isActive: Bool) -> some View {
        modifier(ErrorFlashModifier(isActive: isActive))
    }

    func primaryGlow() -> some View {
        glow(color: Color(hex: "#9A8CFF"), radius: 12, opacity: 0.15)
    }

    func buttonGlow() -> some View {
        glow(color: Color(hex: "#7C6CFF"), radius: 16, opacity: 0.25)
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
