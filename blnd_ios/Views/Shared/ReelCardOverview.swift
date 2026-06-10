import SwiftUI

// MARK: - Overview (Expandable)

extension ReelCardView {
    /// Whether the card has a tagline ("hero description") above the
    /// overview. When it does, overview can disappear entirely under
    /// pressure; when it doesn't, overview holds at least 1 line to
    /// act as the tagline stand-in.
    var hasTagline: Bool {
        let real = movie.tagline ?? ""
        let tag = APIConfig.screenshotMode
            ? ScreenshotDummy.tagline(for: movie.tmdbId)
            : real
        return !tag.isEmpty
    }

    var overviewText: String {
        let real = movie.overview ?? ""
        return APIConfig.screenshotMode
            ? ScreenshotDummy.overview(for: movie.tmdbId)
            : real
    }

    /// Overview Text for the expanded state (full content, unbounded).
    @ViewBuilder
    var cardOverview: some View {
        if !overviewText.isEmpty {
            Text(overviewText)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
