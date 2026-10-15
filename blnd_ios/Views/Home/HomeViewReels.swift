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
            } else if fypReelMovies.isEmpty, catalogFilters.filter.media == .tv {
                Spacer()
                CatalogFilterNotice(title: "TV recommendations are coming soon")
                Spacer()
            } else if fypReelMovies.isEmpty, catalogFilters.filter.isActive {
                Spacer()
                CatalogFilterNotice(title: "Nothing matches this filter")
                Spacer()
            } else {
                ReelsFeedView(
                    movies: fypReelMovies,
                    feed: .fyp,
                    isTabVisible: tabState.selectedTab == 0,
                    onLoadMore: { await loadMoreFYP() },
                    onRefresh: { await refreshFYP() },
                    externalCurrentId: $fypCurrentId
                )
            }
        case .discover:
            DiscoverSectionView(
                cardWidth: 0,
                cardHeight: 0,
                viewMode: .reels,
                isTabVisible: tabState.selectedTab == 0,
                externalCurrentId: $discoverCurrentId
            )
        }
    }
}
