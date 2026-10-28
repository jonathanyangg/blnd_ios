import SwiftUI

/// The one movie detail surface for the reel feed, grid, and search. Reuses
/// `MovieDetailView`; dragging the sheet down returns to where the user was.
struct MovieDetailSheet: View {
    let tmdbId: Int
    var title: String = ""
    var source: Analytics.DetailSource
    var onHide: (() -> Void)?

    var body: some View {
        NavigationStack {
            MovieDetailView(tmdbId: tmdbId, title: title, source: source, onHide: onHide)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.sheet")
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppTheme.background)
    }
}

/// A movie to show in `MovieDetailSheet`.
struct MovieDetailItem: Identifiable, Hashable {
    let tmdbId: Int
    var title: String = ""
    var id: Int {
        tmdbId
    }
}
