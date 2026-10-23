import SwiftUI

// MARK: - Actions & Data Loading

extension DiscoverSectionView {
    func selectFilter(_ filter: DiscoverFilter) {
        let changed = activeFilter != filter
        activeFilter = filter

        guard changed else { return }
        resetPagination()
        if filter == .genre, selectedGenres.isEmpty { return }
        Task { await loadMovies(forceRefresh: true) }
    }

    func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else if selectedGenres.count < 3 {
            selectedGenres.insert(genre)
        }

        activeFilter = .genre
        resetPagination()
        if !selectedGenres.isEmpty {
            Task { await loadMovies(forceRefresh: true) }
        }
    }

    func resetPagination() {
        movies = []
        discoverReelMovies = []
        seenIds = []
        errorMessage = nil
        hasMorePages = true
    }

    func loadMovies(forceRefresh: Bool = false) async {
        guard forceRefresh || movies.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        seenIds = []
        do {
            let filter = catalogFilters.current()
            let response = try await fetchBatch(exclude: [], filter: filter)
            guard !Task.isCancelled else { return }
            seenIds = Set(response.results.map(\.tmdbId))
            let visible = response.results.filter {
                filter.matches(mediaType: $0.mediaType, year: $0.year)
            }
            movies = visible
            discoverReelMovies = visible.map { ReelMovie(from: $0) }
            hasMorePages = !response.results.isEmpty
        } catch {
            if !Task.isCancelled {
                errorMessage = UserFacingError.capture(error, screen: "Discover")
            }
        }
        isLoading = false
    }

    func loadNextPage() async {
        guard hasMorePages, !isLoading, !isLoadingMore
        else { return }
        isLoadingMore = true
        let batchNum = (seenIds.count / 20) + 1
        Analytics.feedLoadMore(source: .discover, batchNum: batchNum)
        do {
            let filter = catalogFilters.current()
            let response = try await fetchBatch(exclude: seenIds, filter: filter)
            for movie in response.results {
                seenIds.insert(movie.tmdbId)
            }
            let newMovies = response.results.filter {
                filter.matches(mediaType: $0.mediaType, year: $0.year)
            }
            if response.results.isEmpty || response.results.count < 20 {
                hasMorePages = false
            }
            if !newMovies.isEmpty {
                movies.append(contentsOf: newMovies)
                discoverReelMovies.append(
                    contentsOf: newMovies.map { ReelMovie(from: $0) }
                )
            }
        } catch {
            if !Task.isCancelled {
                hasMorePages = false
            }
        }
        isLoadingMore = false
    }

    func fetchBatch(
        exclude: Set<Int>,
        filter: CatalogFilter
    ) async throws -> MovieSearchResult {
        // Actor filter overrides to discover endpoint
        if let actor = selectedActor {
            return try await MoviesAPI.discover(
                genres: activeFilter == .genre ? Array(selectedGenres) : [],
                withCast: actor.id,
                exclude: exclude,
                filter: filter
            )
        }
        switch activeFilter {
        case .trending:
            return try await MoviesAPI.trending(exclude: exclude, filter: filter)
        case .topRated:
            return try await MoviesAPI.topRated(exclude: exclude, filter: filter)
        case .genre:
            return try await MoviesAPI.discover(
                genres: Array(selectedGenres),
                exclude: exclude,
                filter: filter
            )
        }
    }

    func refresh() async {
        Analytics.feedRefreshed(source: .discover)
        resetPagination()
        await loadMovies(forceRefresh: true)
    }

    // MARK: - Actor Menu

    var actorMenuButton: some View {
        HStack(spacing: 4) {
            Button { showActorSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                    if let actor = selectedActor {
                        Text(String(actor.name.prefix(15)))
                            .font(.system(size: 12, weight: .medium))
                    } else {
                        Text("Actor")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    selectedActor != nil
                        ? .white : AppTheme.card
                )
                .foregroundStyle(
                    selectedActor != nil
                        ? .black : AppTheme.textMuted
                )
                .clipShape(Capsule())
            }

            if selectedActor != nil {
                Button {
                    selectedActor = nil
                    resetPagination()
                    Task { await loadMovies(forceRefresh: true) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(5)
                        .background(.white)
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showActorSheet) {
            ActorSearchSheet { person in
                selectedActor = person
                resetPagination()
                if activeFilter == .genre, selectedGenres.isEmpty {
                    activeFilter = .genre
                }
                Task { await loadMovies(forceRefresh: true) }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
    }
}
