import SwiftUI

struct ReelSwipeIndicator: View {
    let offset: CGFloat
    let threshold: CGFloat
    let isLeft: Bool

    private var progress: CGFloat {
        min(abs(offset) / threshold, 1.0)
    }

    private var crossed: Bool {
        abs(offset) >= threshold
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(
                systemName: isLeft
                    ? "bookmark.fill" : "star.fill"
            )
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(
                crossed ? (isLeft ? .blue : .yellow)
                    : .white
            )

            Text(isLeft ? "Watchlist" : "Rate")
                .font(.system(
                    size: 12, weight: .semibold
                ))
                .foregroundStyle(.white)
        }
        .opacity(Double(progress) * 0.9)
        .scaleEffect(0.7 + Double(progress) * 0.3)
        .animation(
            .easeOut(duration: 0.15), value: crossed
        )
    }
}
