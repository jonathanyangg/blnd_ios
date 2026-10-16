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
            async let recsResult = GroupsAPI.getFeed(
                groupId: groupId
            )
            async let watchlistResult = GroupsAPI.getWatchlist(
                groupId: groupId
            )

            let (groupData, recsData, watchlistData) = try await (
                groupResult, recsResult, watchlistResult
            )
            group = groupData
            recommendations = recsData.results
            seenRecIds = Set(recsData.results.map(\.tmdbId))
            groupReelMovies = recsData.results.map { ReelMovie(from: $0) }
            watchlist = watchlistData.results
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
            let response = try await GroupsAPI.getFeed(
                groupId: groupId,
                exclude: Array(seenRecIds)
            )
            let newMovies = response.results.filter {
                !seenRecIds.contains($0.tmdbId)
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
