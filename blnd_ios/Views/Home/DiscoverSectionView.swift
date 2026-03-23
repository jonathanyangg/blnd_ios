import SwiftUI

enum DiscoverFilter: String, CaseIterable {
    case trending = "Trending"
    case topRated = "Top Rated"
    case genre = "Genre"
    case describe = "Describe"
}

let discoverGenres = [
    "Action", "Comedy", "Horror", "Sci-Fi", "Romance",
    "Thriller", "Drama", "Animation", "Documentary",
    "Mystery", "Fantasy", "Crime",
]

struct DiscoverSectionView: View {
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    var viewMode: ViewMode = .grid

    @State var activeFilter: DiscoverFilter = .trending
    @State var movies: [MovieResponse] = []
    @State var discoverReelMovies: [ReelMovie] = []
    @State var isLoading = false
    @State var errorMessage: String?
    @State var selectedGenres: Set<String> = []
    @State var showGenrePicker = false
    @State var seenIds: Set<Int> = []
    @State var hasMorePages = true
    @State var isLoadingMore = false

    var body: some View {
        VStack(spacing: 0) {
            filterHeader
            if viewMode == .reels {
                reelsFeed
            } else {
                gridFeed
            }
        }
        .task { await loadMovies() }
    }

    // MARK: - Shared Filter Header

    private var filterHeader: some View {
        VStack(spacing: 0) {
            filterChips
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)

            if showGenrePicker {
                genrePickerRow
                    .padding(.bottom, 10)
            }

            Divider().overlay(AppTheme.border)
        }
        .background(AppTheme.background)
    }

    // MARK: - Reels Feed

    @ViewBuilder
    private var reelsFeed: some View {
        if isLoading {
            Spacer()
            ProgressView().tint(.white)
            Spacer()
        } else if let error = errorMessage {
            Spacer()
            reelsError(error)
            Spacer()
        } else if activeFilter == .genre, selectedGenres.isEmpty {
            Spacer()
            genreEmptyState
            Spacer()
        } else {
            ReelsFeedView(
                movies: discoverReelMovies,
                onLoadMore: { await loadNextPage() },
                onRefresh: { await refresh() }
            )
        }
    }

    private func reelsError(
        _ message: String
    ) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadMovies() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
        }
    }

    // MARK: - Grid Feed

    private var gridFeed: some View {
        contentBody
    }

    // MARK: - Content

    @ViewBuilder
    private var contentBody: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(message: error)
        } else if activeFilter == .genre, selectedGenres.isEmpty {
            genreEmptyState
        } else {
            movieGridView
        }
    }

    private var movieGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(
                Array(movies.enumerated()),
                id: \.element.id
            ) { index, movie in
                NavigationLink {
                    MovieDetailView(
                        tmdbId: movie.tmdbId,
                        title: movie.title
                    )
                } label: {
                    cardView(movie: movie, index: index)
                }
                .buttonStyle(.plain)
                .onAppear {
                    if index == movies.count - 4 {
                        Task { await loadNextPage() }
                    }
                }
            }

            if isLoadingMore {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 24)
    }

    private func cardView(
        movie: MovieResponse,
        index: Int
    ) -> some View {
        MovieCard(
            title: movie.title,
            year: movie.yearString,
            posterPath: movie.posterPath,
            width: cardWidth,
            height: cardHeight,
            scorePercent: movie.matchPercent
        )
        .overlay(alignment: .topLeading) {
            if activeFilter == .trending {
                Text("#\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(6)
            }
        }
    }

    // MARK: - Filter Chips

    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(
                    DiscoverFilter.allCases,
                    id: \.self
                ) { filter in
                    if filter == .describe {
                        describeChip
                    } else {
                        filterButton(filter)
                    }
                }
            }
        }
    }

    private func filterButton(
        _ filter: DiscoverFilter
    ) -> some View {
        Button { selectFilter(filter) } label: {
            Text(filter.rawValue)
                .font(.system(size: 12, weight: .medium))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    activeFilter == filter
                        ? .white : AppTheme.card
                )
                .foregroundStyle(
                    activeFilter == filter
                        ? .black : AppTheme.textMuted
                )
                .clipShape(Capsule())
        }
    }

    private var describeChip: some View {
        Button {} label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                Text("Describe")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(AppTheme.card)
            .foregroundStyle(AppTheme.textDim)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Genre Picker

    var genrePickerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(
                    discoverGenres,
                    id: \.self
                ) { genre in
                    let active =
                        selectedGenres.contains(genre)
                    Button { toggleGenre(genre) } label: {
                        Text(genre)
                            .font(.system(
                                size: 11,
                                weight: .medium
                            ))
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(
                                active ? .white
                                    : AppTheme.card
                            )
                            .foregroundStyle(
                                active ? .black
                                    : AppTheme.textMuted
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    var genreEmptyState: some View {
        VStack(spacing: 8) {
            Text("Pick up to 3 genres")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Select genres above to discover movies")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Shared

    private var loadingView: some View {
        ProgressView()
            .tint(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    private func errorView(
        message: String
    ) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadMovies() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
