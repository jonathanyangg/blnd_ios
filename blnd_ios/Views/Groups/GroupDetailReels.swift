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
                    "Rate more movies to get blend picks"
                )
                Spacer()
            } else {
                ReelsFeedView(
                    movies: groupReelMovies,
                    feed: .blend,
                    isTabVisible: tabState.selectedTab == 1,
                    onLoadMore: { await loadMoreRecs() },
                    onRefresh: { await loadAll(forceRefresh: true) },
                    externalCurrentId: $blendCurrentId
                )
            }
        case .watchlist:
            if watchlist.isEmpty {
                Spacer()
                emptyState(
                    "No movies in the watchlist yet"
                )
                Spacer()
            } else {
                ReelsFeedView(
                    movies: watchlist.map {
                        ReelMovie(from: $0)
                    },
                    feed: .blend,
                    isTabVisible: tabState.selectedTab == 1,
                    onRefresh: { await loadAll(forceRefresh: true) },
                    externalCurrentId: $watchlistCurrentId
                )
            }
        }
    }
}
