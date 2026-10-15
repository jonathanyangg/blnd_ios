import SwiftUI

enum DiscoverFilter: String, CaseIterable {
    case trending = "Trending"
    case topRated = "Top Rated"
    case genre = "Genre"
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
    var isTabVisible: Bool = true
    var externalCurrentId: Binding<Int?>?

    @State var activeFilter: DiscoverFilter = .trending
    @State var movies: [MovieResponse] = []
    @State var discoverReelMovies: [ReelMovie] = []
    @State var isLoading = false
    @State var errorMessage: UserFacingError?
    @State var selectedGenres: Set<String> = []
    @State var showGenreSheet = false
    @State var selectedActor: PersonResult?
    @State var showActorSheet = false
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
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)

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
                feed: .discover,
                isTabVisible: isTabVisible,
                onLoadMore: { await loadNextPage() },
                onRefresh: { await refresh() },
                externalCurrentId: externalCurrentId
            )
        }
    }

    private func reelsError(
        _ message: UserFacingError
    ) -> some View {
        ErrorStateView(message: message) {
            Task { await loadMovies() }
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
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(
                Array(movies.enumerated()),
                id: \.element.id
            ) { index, movie in
                NavigationLink {
                    MovieDetailView(
                        tmdbId: movie.tmdbId,
                        title: movie.title,
                        source: .grid
                    )
                } label: {
                    cardView(movie: movie, index: index)
                }
                .buttonStyle(.plain)
                .id(movie.tmdbId)
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
        .padding(.horizontal, 16)
    }

    private func cardView(
        movie: MovieResponse,
        index: Int
    ) -> some View {
        MovieCard(
            tmdbId: movie.tmdbId,
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
                    filterButton(filter)
                }

                // Actor is a combinable filter, not a tab
                actorMenuButton
            }
        }
    }

    @ViewBuilder
    private func filterButton(
        _ filter: DiscoverFilter
    ) -> some View {
        if filter == .genre {
            genreMenuButton
        } else {
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
    }

    // MARK: - Genre Menu

    private var genreMenuButton: some View {
        Button { showGenreSheet = true } label: {
            HStack(spacing: 4) {
                Text("Genre")
                    .font(.system(size: 12, weight: .medium))
                if selectedGenres.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                } else {
                    Text("\u{00B7} \(selectedGenres.count)")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                !selectedGenres.isEmpty
                    ? .white : AppTheme.card
            )
            .foregroundStyle(
                !selectedGenres.isEmpty
                    ? .black : AppTheme.textMuted
            )
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showGenreSheet) {
            GenrePickerSheet(
                genres: discoverGenres,
                selected: $selectedGenres,
                onChanged: {
                    activeFilter = .genre
                    resetPagination()
                    if !selectedGenres.isEmpty {
                        Task { await loadMovies(forceRefresh: true) }
                    }
                }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
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
        message: UserFacingError
    ) -> some View {
        ErrorStateView(message: message) {
            Task { await loadMovies() }
        }
        .padding(.top, 60)
    }
}
