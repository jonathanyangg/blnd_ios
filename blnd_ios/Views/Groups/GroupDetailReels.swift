import SwiftUI

// MARK: - Reels Mode

extension GroupDetailView {
    @ViewBuilder
    var reelsFeed: some View {
        switch selectedTab {
        case .blendPicks:
            if recommendations.isEmpty {
                Spacer()
                emptyState(
                    "Rate more movies to get group picks"
                )
                Spacer()
            } else {
                ReelsFeedView(
                    movies: groupReelMovies,
                    groupContext: groupContext,
                    onLoadMore: { await loadMoreRecs() }
                )
            }
        case .watchlist:
            if watchlist.isEmpty {
                Spacer()
                emptyState(
                    "No movies in the group watchlist yet"
                )
                Spacer()
            } else {
                ReelsFeedView(
                    movies: watchlist.map {
                        ReelMovie(from: $0)
                    },
                    groupContext: groupContext
                )
            }
        }
    }
}
