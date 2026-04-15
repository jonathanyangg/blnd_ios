import SwiftUI

// MARK: - Actions & Data Loading

extension DiscoverSectionView {
    func selectFilter(_ filter: DiscoverFilter) {
        let changed = activeFilter != filter
        activeFilter = filter

        guard changed else { return }
        resetPagination()
        if filter == .genre, selectedGenres.isEmpty { return }
        if filter == .actor, selectedActor == nil { return }
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
            let response = try await fetchBatch(exclude: [])
            movies = response.results
            seenIds = Set(response.results.map(\.tmdbId))
            discoverReelMovies = response.results.map { ReelMovie(from: $0) }
            hasMorePages = !response.results.isEmpty
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func loadNextPage() async {
        guard hasMorePages, !isLoading, !isLoadingMore
        else { return }
        isLoadingMore = true
        do {
            let response = try await fetchBatch(exclude: seenIds)
            let newMovies = response.results.filter {
                !seenIds.contains($0.tmdbId)
            }
            if newMovies.isEmpty {
                hasMorePages = false
            } else {
                movies.append(contentsOf: newMovies)
                for movie in newMovies {
                    seenIds.insert(movie.tmdbId)
                }
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
        exclude: Set<Int>
    ) async throws -> MovieSearchResult {
        switch activeFilter {
        case .trending:
            return try await MoviesAPI.trending(exclude: exclude)
        case .topRated:
            return try await MoviesAPI.topRated(exclude: exclude)
        case .genre:
            return try await MoviesAPI.discover(
                genres: Array(selectedGenres), exclude: exclude
            )
        case .actor:
            guard let actor = selectedActor else {
                return MovieSearchResult(results: [], totalResults: 0)
            }
            return try await MoviesAPI.discover(
                withCast: actor.id, exclude: exclude
            )
        }
    }

    func refresh() async {
        resetPagination()
        await loadMovies(forceRefresh: true)
    }

    // MARK: - Actor Menu

    var actorMenuButton: some View {
        Button { showActorSheet = true } label: {
            HStack(spacing: 4) {
                if let actor = selectedActor {
                    Text(String(actor.name.prefix(15)))
                        .font(.system(size: 12, weight: .medium))
                } else {
                    Text("Actor")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
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
        .sheet(isPresented: $showActorSheet) {
            ActorSearchSheet { person in
                selectedActor = person
                activeFilter = .actor
                resetPagination()
                Task { await loadMovies(forceRefresh: true) }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
    }

    var actorEmptyState: some View {
        VStack(spacing: 8) {
            Text("Search for an actor")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Tap the Actor chip to find movies by actor")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
