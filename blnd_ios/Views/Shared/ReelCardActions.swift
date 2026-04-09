import PostHog
import SwiftUI

// MARK: - Gestures & Actions

extension ReelCardView {
    var horizontalSwipe: some Gesture {
        DragGesture(minimumDistance: 25)
            .onChanged { value in
                let dxx = abs(value.translation.width)
                let dyy = abs(value.translation.height)
                guard dxx > dyy * 1.5 else { return }
                isDragging = true

                // Clamp offset with rubber-band feel past threshold
                let raw = value.translation.width
                let maxOffset = swipeThreshold + 30
                let clamped = max(-maxOffset, min(maxOffset, raw))
                swipeOffset = clamped

                let crossed = abs(swipeOffset) >= swipeThreshold
                if crossed, !swipeTriggeredHaptic {
                    UIImpactFeedbackGenerator(style: .medium)
                        .impactOccurred()
                    swipeTriggeredHaptic = true
                } else if !crossed, swipeTriggeredHaptic {
                    // Reset haptic when user pulls back below threshold
                    swipeTriggeredHaptic = false
                }
            }
            .onEnded { value in
                let dxx = abs(value.translation.width)
                let dyy = abs(value.translation.height)
                guard dxx > dyy * 1.5 else {
                    resetSwipe()
                    return
                }
                let off = value.translation.width
                if off < -swipeThreshold {
                    Task { await hideMovie() }
                } else if off > swipeThreshold {
                    addToWatchlist()
                }
                resetSwipe()
            }
    }

    func resetSwipe() {
        withAnimation(.easeOut(duration: 0.25)) {
            swipeOffset = 0
            isDragging = false
        }
        swipeTriggeredHaptic = false
    }

    func addToWatchlist() {
        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)
        PostHogSDK.shared.capture("watchlist_added", properties: ["tmdb_id": movie.tmdbId, "source": "reels"])

        // Optimistic — show toast + update cache
        if let ctx = groupContext {
            onWatchlistAdded?(
                "Added to \(ctx.groupName) Watchlist"
            )
        } else {
            UserActionCache.shared.didWatchlist(
                movie.tmdbId
            )
            onWatchlistAdded?("Added to My Watchlist")
        }

        // Fire API in background
        Task {
            do {
                if let ctx = groupContext {
                    _ = try await GroupsAPI.addToWatchlist(
                        groupId: ctx.groupId,
                        tmdbId: movie.tmdbId
                    )
                } else {
                    _ = try await TrackingAPI.addToWatchlist(
                        tmdbId: movie.tmdbId
                    )
                }
            } catch {
                onWatchlistAdded?("Already in Watchlist")
            }
        }
    }

    func loadFriends() {
        if APIConfig.screenshotMode {
            friendsWhoWatched = ScreenshotDummy.friendsWhoWatched()
            return
        }
        let cache = UserActionCache.shared
        if let cached = cache.getFriendsWhoWatched(movie.tmdbId) {
            friendsWhoWatched = cached
            return
        }
        friendsLoadTask?.cancel()
        friendsLoadTask = Task {
            do {
                let response = try await TrackingAPI
                    .friendsWhoWatched(tmdbId: movie.tmdbId)
                if !Task.isCancelled {
                    cache.cacheFriendsWhoWatched(
                        movie.tmdbId, friends: response.results
                    )
                    friendsWhoWatched = response.results
                }
            } catch {
                // Non-fatal
            }
        }
    }

    func hideMovie() async {
        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)
        onWatchlistAdded?("Won't show again")
        do {
            _ = try await RecommendationsAPI.hideMovie(
                tmdbId: movie.tmdbId
            )
            PostHogSDK.shared.capture("movie_hidden", properties: ["tmdb_id": movie.tmdbId])
        } catch {}
    }

    func posterURL(_ path: String) -> URL? {
        URL(
            string: "https://image.tmdb.org/t/p/w780\(path)"
        )
    }
}
