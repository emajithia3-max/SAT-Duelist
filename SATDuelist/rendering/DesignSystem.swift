import SwiftUI

// MARK: - Design System
// Canonical colors, typography, and spacing per UI spec

enum DesignSystem {

    // MARK: - Colors (EXACT per spec)

    enum Colors {
        // Backgrounds
        static let primaryBackground = Color(hex: "#0F1117")
        static let cardBackground = Color(hex: "#171A22")
        static let elevated = Color(hex: "#1E2230")

        // Primary Accent (Purple)
        static let primary = Color(hex: "#7C6CFF")
        static let primaryGlow = Color(hex: "#9A8CFF")
        static let primaryDeep = Color(hex: "#5B4FFF")

        // Gradient (for primary CTAs only)
        static let gradientTop = Color(hex: "#8B7CFF")
        static let gradientBottom = Color(hex: "#6A5CFF")

        // Secondary Accents
        static let blue = Color(hex: "#4DA3FF")
        static let cyan = Color(hex: "#3FE0C5")
        static let orange = Color(hex: "#FF9F43")
        static let red = Color(hex: "#FF5D5D")

        // Text
        static let textPrimary = Color(hex: "#FFFFFF")
        static let textSecondary = Color(hex: "#B6BCD6")
        static let textMuted = Color(hex: "#7E849C")
        static let textDisabled = Color(hex: "#4A4F63")

        // Card/Border
        static let cardBorder = Color(hex: "#2A2F44")
    }

    // MARK: - Typography

    // Custom font names (PostScript names from font files)
    enum FontName {
        static let interRegular = "Inter18pt-Regular"
        static let interMedium = "Inter18pt-Medium"
        static let interSemiBold = "Inter18pt-SemiBold"
        static let interBold = "Inter18pt-Bold"
        static let poppinsSemiBold = "Poppins-SemiBold"
        static let poppinsBold = "Poppins-Bold"
    }

    enum Typography {
        // Screen titles → Poppins Bold 26-28
        static func screenTitle() -> Font {
            .custom(FontName.poppinsBold, size: 27)
        }

        // Card titles → Poppins Semibold 18-20
        static func cardTitle() -> Font {
            .custom(FontName.poppinsSemiBold, size: 19)
        }

        // Body → Inter Regular 14-15
        static func body() -> Font {
            .custom(FontName.interRegular, size: 15)
        }

        // Buttons → Inter Semibold 15
        static func button() -> Font {
            .custom(FontName.interSemiBold, size: 15)
        }

        // XP / streak numbers → Poppins Bold 22-26
        static func number() -> Font {
            .custom(FontName.poppinsBold, size: 24)
        }

        // Small labels
        static func caption() -> Font {
            .custom(FontName.interMedium, size: 12)
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 18
        static let card: CGFloat = 20
        static let button: CGFloat = 26  // Pill style
    }

    // MARK: - Shadows

    enum Shadows {
        static func card() -> some View {
            EmptyView()
                .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        }
    }

    // MARK: - Animations

    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
        static let medium = SwiftUI.Animation.easeOut(duration: 0.4)
        static let progressBar = SwiftUI.Animation.easeOut(duration: 0.4)
    }
}

// MARK: - Gradient Extension

extension LinearGradient {
    static var primaryButton: LinearGradient {
        LinearGradient(
            colors: [
                DesignSystem.Colors.gradientTop,
                DesignSystem.Colors.gradientBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
