import SwiftUI

// MARK: - Reels Mode

extension HomeView {
    @ViewBuilder
    var reelsFeed: some View {
        switch selectedTab {
        case .forYou:
            if isLoadingFYP {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if let error = fypError {
                Spacer()
                errorView(message: error) {
                    Task { await loadForYou() }
                }
                Spacer()
            } else {
                ReelsFeedView(
                    movies: fypReelMovies,
                    onLoadMore: { await loadMoreFYP() },
                    onRefresh: { await refreshFYP() }
                )
            }
        case .discover:
            DiscoverSectionView(
                cardWidth: 0,
                cardHeight: 0,
                viewMode: .reels
            )
        }
    }
}
