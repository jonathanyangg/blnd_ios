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
                    groupContext: groupContext,
                    isTabVisible: tabState.selectedTab == 2,
                    onLoadMore: { await loadMoreRecs() },
                    onRefresh: { await loadAll(forceRefresh: true) }
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
                    groupContext: groupContext,
                    isTabVisible: tabState.selectedTab == 2,
                    onRefresh: { await loadAll(forceRefresh: true) }
                )
            }
        }
    }
}
