import SwiftUI

// MARK: - Data Loading

extension GroupDetailView {
    func loadAll(forceRefresh: Bool = false) async {
        guard forceRefresh || group == nil else { return }
        loadError = nil
        if forceRefresh {
            Analytics.feedRefreshed(source: .blend)
        }
        do {
            async let groupResult = GroupsAPI.getGroup(
                groupId: groupId
            )
            let filter = catalogFilters.current()
            async let recsResult = GroupsAPI.getFeed(
                groupId: groupId,
                filter: filter
            )
            async let watchlistResult = GroupsAPI.getWatchlist(
                groupId: groupId,
                filter: filter
            )

            let (groupData, recsData, watchlistData) = try await (
                groupResult, recsResult, watchlistResult
            )
            guard !Task.isCancelled else { return }
            group = groupData
            seenRecIds = Set(recsData.results.map(\.tmdbId))
            recommendations = recsData.results.filter {
                filter.matches(mediaType: $0.mediaType, year: $0.year)
            }
            groupReelMovies = recommendations.map { ReelMovie(from: $0) }
            watchlist = watchlistData.results.filter {
                filter.matches(mediaType: $0.mediaType, year: $0.year)
            }
        } catch {
            let copy = UserFacingError.capture(error, screen: "Blend")
            if case APIError.rateLimited = error {
                showToast(copy)
            } else if group == nil {
                loadError = copy
            } else {
                showToast(copy) { Task { await loadAll(forceRefresh: true) } }
            }
        }
        isLoading = false
    }

    func loadMoreRecs() async {
        guard !isLoadingMoreRecs, !isLoading else { return }
        isLoadingMoreRecs = true
        let batchNum = (seenRecIds.count / 20) + 1
        Analytics.feedLoadMore(source: .blend, batchNum: batchNum)
        do {
            let filter = catalogFilters.current()
            let response = try await GroupsAPI.getFeed(
                groupId: groupId,
                exclude: Array(seenRecIds),
                filter: filter
            )
            for movie in response.results {
                seenRecIds.insert(movie.tmdbId)
            }
            let newMovies = response.results.filter {
                filter.matches(mediaType: $0.mediaType, year: $0.year)
            }
            if !newMovies.isEmpty {
                recommendations.append(contentsOf: newMovies)
                for movie in newMovies {
                    seenRecIds.insert(movie.tmdbId)
                }
                groupReelMovies.append(
                    contentsOf: newMovies.map { ReelMovie(from: $0) }
                )
            }
        } catch {
            if !Task.isCancelled {
                showToast(UserFacingError.capture(error, screen: "BlendFeed")) {
                    Task { await loadMoreRecs() }
                }
            }
        }
        isLoadingMoreRecs = false
    }

    func saveGroupName() {
        let trimmed = editedName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showToast(.client(.validation, message: "Name can't be empty"))
            return
        }
        guard trimmed.count <= 30 else {
            showToast(.client(.validation, message: "Name must be 30 characters or less"))
            return
        }
        guard trimmed != group?.name else { return }
        let oldName = group?.name ?? ""
        group?.name = trimmed
        Task {
            do {
                _ = try await GroupsService.updateGroup(
                    groupId: groupId, name: trimmed
                )
            } catch {
                group?.name = oldName
                showToast(UserFacingError.capture(error, screen: "RenameBlend"))
            }
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
}
