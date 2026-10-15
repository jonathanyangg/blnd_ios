import SwiftUI

// MARK: - Grid Mode

extension GroupDetailView {
    var gridFeed: some View {
        GeometryReader { geo in
            let cardWidth = (geo.size.width - 24 * 2 - 12) / 2
            let cardHeight = cardWidth * 1.5

            ScrollView {
                VStack(spacing: 0) {
                    switch selectedTab {
                    case .blendPicks:
                        blendPicksGrid(
                            cardWidth: cardWidth,
                            cardHeight: cardHeight
                        )
                    case .watchlist:
                        watchlistGrid(
                            cardWidth: cardWidth,
                            cardHeight: cardHeight
                        )
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollPosition(id: gridScrollBinding, anchor: .top)
        }
    }

    private var gridScrollBinding: Binding<Int?> {
        switch selectedTab {
        case .blendPicks: $blendCurrentId
        case .watchlist: $watchlistCurrentId
        }
    }

    // MARK: - Blend Picks Grid

    func blendPicksGrid(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        Group {
            if recommendations.isEmpty {
                emptyState(
                    "Rate more movies to get blend picks"
                )
            } else {
                movieGrid {
                    ForEach(
                        Array(
                            recommendations.enumerated()
                        ),
                        id: \.element.id
                    ) { index, movie in
                        NavigationLink {
                            MovieDetailView(
                                tmdbId: movie.tmdbId,
                                title: movie.title,
                                source: .grid
                            )
                        } label: {
                            MovieCard(
                                tmdbId: movie.tmdbId,
                                title: movie.title,
                                year: movie.yearString,
                                posterPath: movie.posterPath,
                                width: cardWidth,
                                height: cardHeight,
                                scorePercent: movie
                                    .scorePercent,
                                mediaType: movie.mediaType
                            )
                        }
                        .buttonStyle(.plain)
                        .id(movie.tmdbId)
                        .onAppear {
                            if index >= recommendations.count - 4 {
                                Task { await loadMoreRecs() }
                            }
                        }
                    }

                    if isLoadingMoreRecs {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
        }
    }

    // MARK: - Watchlist Grid

    func watchlistGrid(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        Group {
            if watchlist.isEmpty {
                emptyState(
                    "No movies in the watchlist yet"
                )
            } else {
                movieGrid {
                    ForEach(watchlist) { item in
                        NavigationLink {
                            MovieDetailView(
                                tmdbId: item.tmdbId,
                                source: .watchlist
                            )
                        } label: {
                            MovieCard(
                                tmdbId: item.tmdbId,
                                title: item.title,
                                posterPath: item.posterPath,
                                width: cardWidth,
                                height: cardHeight,
                                scorePercent: item
                                    .matchPercent,
                                mediaType: item.mediaType
                            )
                        }
                        .buttonStyle(.plain)
                        .id(item.tmdbId)
                    }
                }
            }
        }
    }

    // MARK: - Shared

    func movieGrid(
        @ViewBuilder content: () -> some View
    ) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            content()
        }
        .scrollTargetLayout()
        .padding(.horizontal, 24)
    }

    func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }
}
