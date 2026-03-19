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
        errorMessage = nil
        currentPage = 1
        hasMorePages = true
    }

    func loadMovies() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        do {
            let response = try await fetchPage(1)
            movies = response.results
            hasMorePages = movies.count < response.totalResults
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
        let nextPage = currentPage + 1
        do {
            let response = try await fetchPage(nextPage)
            movies.append(contentsOf: response.results)
            currentPage = nextPage
            hasMorePages =
                movies.count < response.totalResults
        } catch {
            if !Task.isCancelled {
                hasMorePages = false
            }
        }
        isLoadingMore = false
    }

    func fetchPage(
        _ page: Int
    ) async throws -> MovieSearchResult {
        switch activeFilter {
        case .trending:
            return try await MoviesAPI.trending(page: page)
        case .topRated:
            return try await MoviesAPI.topRated(page: page)
        case .genre:
            return try await MoviesAPI.discover(
                genres: Array(selectedGenres), page: page
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
