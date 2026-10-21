import SwiftUI

// MARK: - Data Loading

extension HomeView {
    func rebuildReelMovies() {
        fypReelMovies = recommendations.map { ReelMovie(from: $0) }
    }

    func hideMovie(_ tmdbId: Int) {
        guard let index = recommendations.firstIndex(where: { $0.tmdbId == tmdbId }) else { return }
        let movie = recommendations[index]
        withAnimation {
            recommendations.removeAll { $0.tmdbId == tmdbId }
            rebuildReelMovies()
        }
        Task {
            do {
                _ = try await RecommendationsAPI.hideMovie(tmdbId: tmdbId)
            } catch {
                withAnimation {
                    recommendations.insert(movie, at: min(index, recommendations.count))
                    rebuildReelMovies()
                }
                showToast(UserFacingError.capture(error, screen: "HideMovie")) {
                    hideMovie(tmdbId)
                }
            }
        }
    }

    func loadForYou() async {
        guard recommendations.isEmpty else { return }
        if UITestLaunch.screen == .findNowEntry
            || UITestLaunch.screen == .onboardFeed
            || UITestLaunch.screen == .reelTutorial {
            recommendations = NowCatalog.feed
            rebuildReelMovies()
            return
        }
        isLoadingFYP = true
        fypError = nil
        do {
            let filter = catalogFilters.current()
            let page = try await nextFilteredFeed(filter: filter)
            guard !Task.isCancelled else { return }
            if page.isEmpty, let seeded = OnboardingFeedSeed.take() {
                recommendations = seeded
            } else {
                recommendations = page
                _ = OnboardingFeedSeed.take()
            }
            seenFYPIds = Set(recommendations.map(\.tmdbId))
            rebuildReelMovies()
        } catch {
            if !Task.isCancelled, let seeded = OnboardingFeedSeed.take() {
                recommendations = seeded
                seenFYPIds = Set(seeded.map(\.tmdbId))
                rebuildReelMovies()
            } else if !Task.isCancelled {
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
        let copy = UserFacingError.capture(error, screen: "ForYou")
        if case APIError.rateLimited = error {
            showToast(copy)
        } else if recommendations.isEmpty {
            fypError = copy
        } else {
            showToast(copy) { Task { await refreshFYP() } }
        }
    }

    func showToast(_ message: UserFacingError, retry: (() -> Void)? = nil) {
        toastTask?.cancel()
        toastMessage = message
        toastRetry = retry
        toastTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                toastMessage = nil
                toastRetry = nil
            }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        toastMessage = nil
        toastRetry = nil
    }
}
