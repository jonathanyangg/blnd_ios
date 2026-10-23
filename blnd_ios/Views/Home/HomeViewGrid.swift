import SwiftUI

// MARK: - Grid Mode

extension HomeView {
    var gridFeed: some View {
        GeometryReader { geo in
            let cardWidth = (geo.size.width - 16 * 2 - 12) / 2
            let cardHeight = cardWidth * 1.5

            ScrollView {
                VStack(spacing: 0) {
                    switch selectedTab {
                    case .forYou:
                        forYouContent(
                            cardWidth: cardWidth,
                            cardHeight: cardHeight
                        )
                        .padding(.top, 12)
                    case .discover:
                        DiscoverSectionView(
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            viewMode: .grid,
                            externalCurrentId: $discoverCurrentId
                        )
                    }
                }
            }
            .contentMargins(.bottom, 96, for: .scrollContent)
            .sheet(item: $gridDetailItem) { item in
                MovieDetailSheet(tmdbId: item.tmdbId, title: item.title, source: .grid) {
                    withAnimation {
                        recommendations.removeAll { $0.tmdbId == item.tmdbId }
                    }
                }
            }
            .background(AppTheme.background)
            .refreshable { await refreshCurrentTab() }
        }
    }

    func forYouContent(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        Group {
            if isLoadingFYP {
                loadingView
            } else if let error = fypError {
                errorView(message: error) {
                    Task { await loadForYou() }
                }
            } else if recommendations.isEmpty, catalogFilters.filter.media == .tv {
                CatalogFilterNotice(title: "TV recommendations are coming soon")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if recommendations.isEmpty, catalogFilters.filter.isActive {
                CatalogFilterNotice(title: "Nothing matches this filter")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                movieGrid(
                    cardWidth: cardWidth,
                    cardHeight: cardHeight
                )
            }
        }
    }

    func movieGrid(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(
                Array(recommendations.enumerated()),
                id: \.element.id
            ) { index, movie in
                fypGridCard(
                    movie: movie, index: index,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight
                )
                .id(movie.tmdbId)
            }

            if isLoadingMoreFYP {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 16)
    }

    private func fypGridCard(
        movie: RecommendedMovieResponse,
        index: Int,
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        Button {
            gridDetailItem = MovieDetailItem(tmdbId: movie.tmdbId, title: movie.title)
        } label: {
            MovieCard(
                tmdbId: movie.tmdbId,
                title: movie.title,
                year: movie.yearString,
                posterPath: movie.posterPath,
                width: cardWidth,
                height: cardHeight,
                scorePercent: movie.scorePercent,
                mediaType: movie.mediaType
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            if index >= recommendations.count - 4 {
                Task { await loadMoreFYP() }
            }
        }
        .contextMenu {
            Button {
                hideMovie(movie.tmdbId)
            } label: {
                Label("Not for me", systemImage: "eye.slash")
            }
        }
    }

    var loadingView: some View {
        ProgressView()
            .tint(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    func errorView(
        message: UserFacingError,
        retry: @escaping () -> Void
    ) -> some View {
        ErrorStateView(message: message, retry: retry)
            .padding(.top, 60)
    }
}
