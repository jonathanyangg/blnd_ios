import SwiftUI

// MARK: - Data Loading

extension GroupDetailView {
    func loadAll(forceRefresh: Bool = false) async {
        guard forceRefresh || group == nil else { return }
        loadError = nil
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
            if case APIError.rateLimited = error {
                showToast(
                    "Woah, slow down! Try again in a minute"
                )
            } else if group == nil {
                loadError = error.localizedDescription
            } else {
                showToast(error.localizedDescription)
            }
        }
        isLoading = false
    }

    func loadMoreRecs() async {
        guard !isLoadingMoreRecs, !isLoading else { return }
        isLoadingMoreRecs = true
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
                showToast(error.localizedDescription)
            }
        }
        isLoadingMoreRecs = false
    }

    func saveGroupName() {
        let trimmed = editedName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showToast("Name can't be empty")
            isEditingName = false
            return
        }
        guard trimmed.count <= 50 else {
            showToast("Name must be 50 characters or less")
            return
        }
        guard trimmed != group?.name else {
            isEditingName = false
            return
        }
        isEditingName = false
        let oldName = group?.name ?? ""
        group?.name = trimmed
        Task {
            do {
                _ = try await GroupsAPI.updateGroup(
                    groupId: groupId, name: trimmed
                )
            } catch {
                group?.name = oldName
                showToast("Failed to rename blend")
            }
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
}
