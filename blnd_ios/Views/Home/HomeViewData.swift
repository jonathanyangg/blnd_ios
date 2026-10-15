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
            let response = try await RecommendationsAPI.getFeed()
            recommendations = response.results
            seenFYPIds = Set(response.results.map(\.tmdbId))
            rebuildReelMovies()
        } catch {
            if !Task.isCancelled {
                handleLoadError(error)
            }
        }
        isLoadingFYP = false
    }

    func loadMoreFYP() async {
        guard !isLoadingMoreFYP, !isLoadingFYP else { return }
        isLoadingMoreFYP = true
        let batchNum = (seenFYPIds.count / 20) + 1
        Analytics.feedLoadMore(source: .fyp, batchNum: batchNum)
        do {
            let response = try await RecommendationsAPI.getFeed(
                exclude: Array(seenFYPIds)
            )
            let newMovies = response.results.filter {
                !seenFYPIds.contains($0.tmdbId)
            }
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
            let resp = try await RecommendationsAPI.refresh()
            recommendations = resp.results
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
