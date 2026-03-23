import SwiftUI

// MARK: - Data Loading

extension HomeView {
    func hideMovie(_ tmdbId: Int) {
        withAnimation {
            recommendations.removeAll { $0.tmdbId == tmdbId }
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
        do {
            let resp = try await RecommendationsAPI.refresh()
            recommendations = resp.results
            seenFYPIds = Set(resp.results.map(\.tmdbId))
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
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            dismissToast()
        }
    }

    func dismissToast() {
        toastMessage = nil
    }
}
