import SwiftUI

// MARK: - Data Loading

extension HomeView {
    func rebuildReelMovies() {
        fypReelMovies = recommendations.map { ReelMovie(from: $0) }
    }

    func hideMovie(_ tmdbId: Int) {
        withAnimation {
            recommendations.removeAll { $0.tmdbId == tmdbId }
            fypReelMovies.removeAll { $0.tmdbId == tmdbId }
        }
        Task {
            _ = try? await RecommendationsAPI.hideMovie(
                tmdbId: tmdbId
            )
        }
    }

    func loadForYou() async {
        guard recommendations.isEmpty else { return }
        isLoadingFYP = true
        fypError = nil
        do {
            let filter = catalogFilters.current()
            let page = try await nextFilteredFeed(filter: filter)
            guard !Task.isCancelled else { return }
            recommendations = page
            rebuildReelMovies()
        } catch {
            if !Task.isCancelled {
                handleLoadError(error)
            }
        }
        guard !Task.isCancelled else { return }
        isLoadingFYP = false
    }

    /// Requests up to three pages so a client-side filter can still fill the feed.
    /// shortcut: stops after 3 pages, so a filter the backend ignores can stay short until media_type and year params are honored.
    func nextFilteredFeed(filter: CatalogFilter) async throws -> [RecommendedMovieResponse] {
        var matched: [RecommendedMovieResponse] = []
        var pages = 0
        while matched.isEmpty, pages < 3 {
            if Task.isCancelled { return [] }
            pages += 1
            let response = try await RecommendationsAPI.getFeed(
                exclude: Array(seenFYPIds),
                filter: filter
            )
            if Task.isCancelled { return [] }
            if response.results.isEmpty { break }
            for movie in response.results {
                seenFYPIds.insert(movie.tmdbId)
            }
            matched = response.results.filter {
                filter.matches(mediaType: $0.mediaType, year: $0.year)
            }
            if response.results.count < 20 { break }
        }
        return matched
    }

    func loadMoreFYP() async {
        guard !isLoadingMoreFYP, !isLoadingFYP else { return }
        isLoadingMoreFYP = true
        let batchNum = (seenFYPIds.count / 20) + 1
        Analytics.feedLoadMore(source: .fyp, batchNum: batchNum)
        do {
            let filter = catalogFilters.current()
            let newMovies = try await nextFilteredFeed(filter: filter)
            if !newMovies.isEmpty {
                recommendations.append(contentsOf: newMovies)
                for movie in newMovies {
                    seenFYPIds.insert(movie.tmdbId)
                }
                fypReelMovies.append(
                    contentsOf: newMovies.map { ReelMovie(from: $0) }
                )
            }
        } catch {
            if !Task.isCancelled {
                handleLoadError(error)
            }
        }
        isLoadingMoreFYP = false
    }

    func refreshFYP() async {
        fypError = nil
        Analytics.feedRefreshed(source: .fyp)
        do {
            let filter = catalogFilters.current()
            let resp = try await RecommendationsAPI.refresh(filter: filter)
            recommendations = resp.results.filter {
                filter.matches(mediaType: $0.mediaType, year: $0.year)
            }
            seenFYPIds = Set(resp.results.map(\.tmdbId))
            rebuildReelMovies()
        } catch {
            if !Task.isCancelled {
                handleLoadError(error)
            }
        }
    }

    func refreshCurrentTab() async {
        switch selectedTab {
        case .forYou:
            await refreshFYP()
        case .discover:
            break
        }
    }

    func handleLoadError(_ error: Error) {
        if case APIError.rateLimited = error {
            showToast("Woah, slow down! Try again in a minute")
        } else if recommendations.isEmpty {
            fypError = error.localizedDescription
        } else {
            showToast(error.localizedDescription)
        }
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                toastMessage = nil
            }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        toastMessage = nil
    }
}
