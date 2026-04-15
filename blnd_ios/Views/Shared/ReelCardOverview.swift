import SwiftUI

// MARK: - Overview (Expandable)

extension ReelCardView {
    /// True when the rendered Text is shorter than its full intrinsic
    /// height, meaning SwiftUI truncated it to fit the available space.
    var isOverviewTruncated: Bool {
        overviewFullHeight > overviewCappedHeight + 1
    }

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
            overviewTextView(lineCap: nil)
        }
    }

    /// Parameterized Text renderer so each ViewThatFits variant can use
    /// a different lineLimit. `.fixedSize(vertical)` keeps the Text rigid
    /// at its intrinsic height for that cap (no overlap with siblings).
    func overviewTextView(lineCap: Int?) -> some View {
        Text(overviewText)
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textMuted)
            .lineSpacing(3)
            .lineLimit(lineCap)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(GeometryReader { geo in
                Color.clear.preference(
                    key: OverviewTruncH.self,
                    value: geo.size.height
                )
            })
            .background(overviewMeasurer(overviewText))
            .onPreferenceChange(OverviewFullH.self) {
                overviewFullHeight = $0
            }
            .onPreferenceChange(OverviewTruncH.self) {
                overviewCappedHeight = $0
            }
    }

    func overviewMeasurer(_ text: String) -> some View {
        // Hidden sibling that reports the full intrinsic height of the
        // overview. Compared against the visible Text's rendered height
        // to decide whether to show the "more" button.
        Text(text)
            .font(.system(size: 13))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .background(GeometryReader { geo in
                Color.clear.preference(
                    key: OverviewFullH.self,
                    value: geo.size.height
                )
            })
    }
}
