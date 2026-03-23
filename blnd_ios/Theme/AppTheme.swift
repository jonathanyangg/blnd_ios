import SwiftUI

enum AppTheme {
    // MARK: - Colors

    static let background = Color(hex: 0x000000)
    static let card = Color(hex: 0x1A1A1A)
    static let cardSecondary = Color(hex: 0x2A2A2A)
    static let border = Color(hex: 0x333333)
    static let textPrimary = Color.white
    static let textMuted = Color(hex: 0x999999)
    static let textDim = Color(hex: 0x666666)
    static let destructive = Color(hex: 0xFF3B30)
    static let aiPurple = Color(hex: 0x8B7BB5)
    static let aiGradient = LinearGradient(
        colors: [Color(hex: 0x9B8BC5), Color(hex: 0xC4B5E0)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Corner Radii

    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 14
    static let cornerRadiusPill: CGFloat = 20
    static let cornerRadiusSheet: CGFloat = 20

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24
    static let spacingHuge: CGFloat = 32

    // MARK: - Poster Gradients

    static let posterGradient = LinearGradient(
        colors: [Color(hex: 0x1A3A5C), Color(hex: 0xC0392B)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func posterGradient(angle: Int) -> LinearGradient {
        // Approximate rotation via shifting start/end points
        let normalizedAngle = Double(angle % 360) / 360.0
        let startX = cos(normalizedAngle * .pi * 2) * 0.5 + 0.5
        let startY = sin(normalizedAngle * .pi * 2) * 0.5 + 0.5
        return LinearGradient(
            colors: [Color(hex: 0x1A3A5C), Color(hex: 0xC0392B)],
            startPoint: UnitPoint(x: 1 - startX, y: 1 - startY),
            endPoint: UnitPoint(x: startX, y: startY)
        )
    }

    static let avatarGradient = LinearGradient(
        colors: [Color(hex: 0x2C3E50), Color(hex: 0x3498DB)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let reelScrimGradient = LinearGradient(
        colors: [.clear, Color.black.opacity(0.7)],
        startPoint: .center,
        endPoint: .bottom
    )
}

// MARK: - Screenshot Mode Blur

extension View {
    /// Blurs poster/backdrop images when screenshot mode is on.
    func posterBlur() -> some View {
        blur(
            radius: APIConfig.screenshotMode ? 20 : 0
        )
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
