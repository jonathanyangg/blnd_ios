import SwiftUI

struct ReelSwipeIndicator: View {
    let offset: CGFloat
    let threshold: CGFloat
    let isLeft: Bool

    private var progress: CGFloat {
        min(abs(offset) / threshold, 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: isLeft ? "bookmark.fill" : "star.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)

            Text(isLeft ? "Watchlist" : "Rate")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .opacity(Double(progress) * 0.9)
        .scaleEffect(0.8 + Double(progress) * 0.2)
    }
}
