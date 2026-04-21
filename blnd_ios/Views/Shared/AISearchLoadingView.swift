import SwiftUI

struct AISearchLoadingView: View {
    @State private var progress: CGFloat = 0
    @State private var messageIndex = 0
    @State private var textOpacity: Double = 1

    private let messages = [
        "Analyzing your request",
        "Searching our catalog",
        "Finding the perfect matches",
        "Curating your results",
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Progress bar
            RoundedRectangle(cornerRadius: 3)
                .fill(AppTheme.card)
                .frame(width: 200, height: 4)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.premiumGoldGradient)
                        .frame(width: 200 * progress, height: 4)
                }

            // Rotating text
            Text(messages[messageIndex])
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
                .opacity(textOpacity)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Progress bar: fills over ~8 seconds, slowing down near the end
        withAnimation(.easeOut(duration: 8)) {
            progress = 0.92
        }

        // Rotate messages every 2 seconds
        rotateMessage()
    }

    private func rotateMessage() {
        let nextIndex = (messageIndex + 1) % messages.count
        // Fade out
        withAnimation(.easeOut(duration: 0.3)) {
            textOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            messageIndex = nextIndex
            // Fade in
            withAnimation(.easeIn(duration: 0.3)) {
                textOpacity = 1
            }
        }
        // Schedule next rotation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            rotateMessage()
        }
    }
}
