import SwiftUI

// MARK: - Data Loading + Actions

extension FriendProfileView {
    func loadData() async {
        isLoading = true
        profileError = nil
        watchedError = nil
        watchedGated = false

        // Profile + mutuals always load (no friendship required)
        async let profile = ProfileAPI.getPublicProfile(userId: friend.id)
        async let mutuals = FriendsAPI.getMutuals(userId: friend.id)
        do {
            let (profileResult, mutualsResult) = try await (profile, mutuals)
            publicProfile = profileResult
            mutualFriends = mutualsResult.mutuals
            mutualCount = mutualsResult.count
        } catch is CancellationError {
            return
        } catch {
            profileError = error.localizedDescription
            isLoading = false
            return
        }

        await fetchWatched()
        isLoading = false
    }

    /// 403 or a not-friends message means the viewer is not friends yet.
    private func fetchWatched() async {
        watchedRequest += 1
        let request = watchedRequest
        watchedError = nil
        do {
            let filter = catalogFilters.current()
            let watchedResult = try await ProfileAPI.getPublicWatched(
                userId: friend.id,
                limit: 20,
                offset: 0,
                sort: watchedSort,
                filter: filter
            )
            guard request == watchedRequest else { return }
            watchedFetchedCount = watchedResult.results.count
            watchedMovies = watchedResult.results.filter {
                filter.matches(mediaType: $0.mediaType, year: $0.year)
            }
            watchedTotal = watchedResult.total
            watchedGated = false
        } catch is CancellationError {
            return
        } catch let error as APIError {
            guard request == watchedRequest else { return }
            if case let .badRequest(info) = error,
               info.code == "NOT_FRIENDS"
                || info.raw.localizedCaseInsensitiveContains("not friends") {
                watchedGated = true
                watchedError = nil
            } else {
                watchedGated = false
                watchedError = error.localizedDescription
            }
        } catch {
            guard request == watchedRequest else { return }
            watchedGated = false
            watchedError = error.localizedDescription
        }
    }

    func loadMoreWatched() async {
        guard !isLoadingMore, watchedMovies.count < watchedTotal else { return }
        isLoadingMore = true
        let request = watchedRequest
        do {
            let filter = catalogFilters.current()
            let next = try await ProfileAPI.getPublicWatched(
                userId: friend.id,
                limit: 20,
                offset: watchedFetchedCount,
                sort: watchedSort,
                filter: filter
            )
            if request == watchedRequest {
                watchedFetchedCount += next.results.count
                watchedMovies.append(contentsOf: next.results.filter {
                    filter.matches(mediaType: $0.mediaType, year: $0.year)
                })
            }
        } catch is CancellationError {
            return
        } catch { /* Non-critical — pagination stops */ }
        isLoadingMore = false
    }

    func reloadWatched() async {
        guard !watchedGated else { return }
        watchedError = nil
        watchedRequest += 1
        let request = watchedRequest
        do {
            let filter = catalogFilters.current()
            let result = try await ProfileAPI.getPublicWatched(
                userId: friend.id,
                limit: 20,
                offset: 0,
                sort: watchedSort,
                filter: filter
            )
            guard request == watchedRequest else { return }
            watchedFetchedCount = result.results.count
            watchedMovies = result.results.filter {
                filter.matches(mediaType: $0.mediaType, year: $0.year)
            }
            watchedTotal = result.total
        } catch is CancellationError {
            return
        } catch {
            guard request == watchedRequest else { return }
            watchedError = error.localizedDescription
        }
    }

    func loadTaste() async {
        isLoadingTaste = true
        do {
            genreTaste = try await ProfileAPI.getPublicTaste(userId: friend.id)
        } catch is CancellationError {
            return
        } catch { /* Non-critical — "not enough ratings" fallback shown */ }
        isLoadingTaste = false
    }

    func loadFriends() async {
        isLoadingFriends = true
        friendsList = []
        do {
            let response = try await ProfileAPI.getPublicFriends(userId: friend.id)
            friendsList = response.friends
        } catch is CancellationError {
            return
        } catch { /* Non-critical — empty list shown */ }
        isLoadingFriends = false
    }

    func removeFriend() async {
        guard let fid = currentFriendshipId else { return }
        isRemoving = true
        do {
            try await FriendsService.removeFriend(friendshipId: fid)
            if currentStatus == "accepted" {
                dismiss()
            } else {
                friendshipAction = nil
                publicProfile = nil
                Task { await loadData() }
            }
        } catch { /* Non-critical — user can retry */ }
        isRemoving = false
    }

    func blockUser() async {
        isBlocking = true
        do {
            try await FriendsService.blockUser(userId: friend.id)
            blockOverride = .blocked
            friendshipAction = nil
        } catch { /* Non-critical — user can retry */ }
        isBlocking = false
    }

    func unblockUser() async {
        isBlocking = true
        do {
            try await FriendsAPI.unblockUser(userId: friend.id)
            blockOverride = .unblocked
        } catch { /* Non-critical — user can retry */ }
        isBlocking = false
    }

    func sendFriendRequest() async {
        isSendingRequest = true
        do {
            _ = try await FriendsService.sendRequest(username: friend.username)
            friendshipAction = "pending"
            Analytics.friendRequestSent()
        } catch { /* Non-critical */ }
        isSendingRequest = false
    }

    func submitReport(_ reason: String) {
        guard !isReporting else { return }
        isReporting = true
        Task {
            defer { isReporting = false }
            do {
                try await FriendsAPI.reportUser(userId: friend.id, reason: reason)
            } catch {
                // Non-fatal — still show confirmation so user knows we heard them
            }
            showReportConfirmation = true
        }
    }
}

// MARK: - Profile Menu

extension FriendProfileView {
    @ViewBuilder
    var profileMenu: some View {
        let isSelf = friend.id == (KeychainManager.readString(key: "userId") ?? "")
        if isSelf {
            EmptyView()
        } else if publicProfile == nil {
            EmptyView()
        } else if isBlocking {
            ProgressView().tint(.white).controlSize(.small)
        } else if isCurrentlyBlocked {
            Menu {
                Button("Unblock", role: .destructive) {
                    showUnblockAlert = true
                }
            } label: {
                menuLabel
            }
        } else {
            Menu {
                profileMenuActions
            } label: {
                menuLabel
            }
        }
    }

    @ViewBuilder
    private var profileMenuActions: some View {
        if currentStatus == "accepted" {
            Button("Remove", role: .destructive) {
                showRemoveAlert = true
            }
        } else if currentStatus == "pending" {
            Button("Withdraw", role: .destructive) {
                showRemoveAlert = true
            }
        } else {
            Button("Add Friend") {
                Task { await sendFriendRequest() }
            }
        }

        Button("Report", role: .destructive) {
            showReportDialog = true
        }

        Button("Block", role: .destructive) {
            showBlockAlert = true
        }
    }

    private var menuLabel: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
    }
}
