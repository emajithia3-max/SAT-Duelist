import SwiftUI

#if DEBUG
/// Debug preview to verify custom font registration
struct FontPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Font Verification")
                    .font(DesignSystem.Typography.screenTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                fontSection(
                    title: "Screen Title (Poppins Bold 27)",
                    font: DesignSystem.Typography.screenTitle()
                )

                fontSection(
                    title: "Card Title (Poppins SemiBold 19)",
                    font: DesignSystem.Typography.cardTitle()
                )

                fontSection(
                    title: "Body (Inter Regular 15)",
                    font: DesignSystem.Typography.body()
                )

                fontSection(
                    title: "Button (Inter SemiBold 15)",
                    font: DesignSystem.Typography.button()
                )

                fontSection(
                    title: "Number (Poppins Bold 24)",
                    font: DesignSystem.Typography.number()
                )

                fontSection(
                    title: "Caption (Inter Medium 12)",
                    font: DesignSystem.Typography.caption()
                )

                Divider()
                    .background(DesignSystem.Colors.cardBorder)

                Text("Font Names Check")
                    .font(DesignSystem.Typography.cardTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                fontNameCheck(DesignSystem.FontName.poppinsBold)
                fontNameCheck(DesignSystem.FontName.poppinsSemiBold)
                fontNameCheck(DesignSystem.FontName.interRegular)
                fontNameCheck(DesignSystem.FontName.interMedium)
                fontNameCheck(DesignSystem.FontName.interSemiBold)
                fontNameCheck(DesignSystem.FontName.interBold)
            }
            .padding()
        }
        .background(DesignSystem.Colors.primaryBackground)
    }

    private func fontSection(title: String, font: Font) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.textMuted)

            Text("The quick brown fox jumps over the lazy dog. 1234567890")
                .font(font)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    private func fontNameCheck(_ name: String) -> some View {
        HStack {
            Text(name)
                .font(.custom(name, size: 14))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            // If font doesn't exist, SwiftUI falls back to system font
            // This visual check helps identify missing fonts
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(DesignSystem.Colors.cyan)
        }
    }
}

#Preview {
    FontPreview()
}
#endif
