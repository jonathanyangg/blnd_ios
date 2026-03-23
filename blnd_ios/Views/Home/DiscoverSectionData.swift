import SwiftUI

// MARK: - Actions & Data Loading

extension DiscoverSectionView {
    func selectFilter(_ filter: DiscoverFilter) {
        let changed = activeFilter != filter
        activeFilter = filter
        showGenrePicker = filter == .genre

        guard changed else { return }
        resetPagination()
        if filter == .genre, selectedGenres.isEmpty { return }
        Task { await loadMovies() }
    }

    func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else if selectedGenres.count < 3 {
            selectedGenres.insert(genre)
        }

        resetPagination()
        if !selectedGenres.isEmpty {
            Task { await loadMovies() }
        }
    }

    func resetPagination() {
        movies = []
        seenIds = []
        errorMessage = nil
        hasMorePages = true
    }

    func loadMovies() async {
        isLoading = true
        errorMessage = nil
        seenIds = []
        do {
            let response = try await fetchBatch(exclude: [])
            movies = response.results
            seenIds = Set(response.results.map(\.tmdbId))
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
        case .describe:
            throw CancellationError()
        }
    }

    func refresh() async {
        resetPagination()
        await loadMovies()
    }
}
