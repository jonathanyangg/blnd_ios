import SwiftUI

extension ProfileView {
    func loadUnreadCount() async {
        do {
            let response = try await NotificationAPI.getInbox(limit: 1)
            unreadCount = response.unreadCount
        } catch {
            return
        }
    }

    func loadTaste() async {
        isLoadingTaste = true
        do {
            genreTaste = try await ProfileAPI.getGenreTaste()
        } catch is CancellationError {
            return
        } catch {
            isLoadingTaste = false
            return
        }
        isLoadingTaste = false
    }

    func refreshAll() async {
        UserActionCache.shared.invalidateGroups()
        UserActionCache.shared.invalidateFriends()
        async let watched: () = loadWatched()
        async let watchlist: () = loadWatchlist()
        async let counts: () = loadCounts()
        async let taste: () = loadTaste()
        async let unread: () = loadUnreadCount()
        _ = await (watched, watchlist, counts, taste, unread)
        diaryReload += 1
        await authState.fetchCurrentUser()
    }
}
