import SwiftUI

// MARK: - Data Loading

extension GroupDetailView {
    func loadAll(forceRefresh: Bool = false) async {
        guard forceRefresh || group == nil else { return }
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
            watchlist = watchlistData.results
        } catch {
            if case APIError.rateLimited = error {
                showToast(
                    "Woah, slow down! Try again in a minute"
                )
            } else if group == nil {
                print("[GroupDetailView] Load failed: \(error)")
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
            }
        } catch {
            if !Task.isCancelled {
                showToast(error.localizedDescription)
            }
        }
        isLoadingMoreRecs = false
    }

    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            toastMessage = nil
        }
    }

    func submitRename() {
        isEditingName = false
        Task { await saveGroupName() }
    }

    func saveGroupName() async {
        let trimmed = editName.trimmingCharacters(
            in: .whitespaces
        )
        guard !trimmed.isEmpty else { return }
        do {
            group = try await GroupsAPI.updateGroup(
                groupId: groupId,
                name: trimmed
            )
        } catch {
            print("[GroupDetailView] Rename failed: \(error)")
        }
    }
}
