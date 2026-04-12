import PostHog
import SwiftUI

// MARK: - Data Loading + Actions

extension FriendProfileView {
    func loadData() async {
        isLoading = true

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
        } catch { /* Non-critical */ }

        // Watched movies require friendship — 403 means not friends yet
        do {
            let watchedResult = try await ProfileAPI.getPublicWatched(
                userId: friend.id, limit: 20, offset: 0
            )
            watchedMovies = watchedResult.results
            watchedTotal = watchedResult.total
        } catch is CancellationError {
            return
        } catch {
            // 403 (not friends) or any other error → show gated state
            watchedGated = true
        }

        isLoading = false
    }

    func loadMoreWatched() async {
        guard !isLoadingMore, watchedMovies.count < watchedTotal else { return }
        isLoadingMore = true
        do {
            let next = try await ProfileAPI.getPublicWatched(
                userId: friend.id,
                limit: 20,
                offset: watchedMovies.count
            )
            watchedMovies.append(contentsOf: next.results)
        } catch is CancellationError {
            return
        } catch { /* Non-critical — pagination stops */ }
        isLoadingMore = false
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
            try await FriendsAPI.removeFriend(friendshipId: fid)
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
            try await FriendsAPI.blockUser(userId: friend.id)
            blockOverride = .blocked
            friendshipAction = nil
            UserActionCache.shared.invalidateFriends()
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
            _ = try await FriendsAPI.sendRequest(username: friend.username)
            friendshipAction = "pending"
            PostHogSDK.shared.capture("friend_request_sent")
        } catch { /* Non-critical */ }
        isSendingRequest = false
    }
}
