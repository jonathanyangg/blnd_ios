import SwiftUI

// MARK: - Gestures & Actions

extension ReelCardView {
    /// Scrubber zone: bottom strip of the media where YouTube's progress
    /// bar lives. Drags starting here skip the card swipe so the scrubber
    /// remains usable when controls are visible.
    var scrubberZoneHeight: CGFloat {
        48
    }

    var horizontalSwipe: some Gesture {
        DragGesture(minimumDistance: 25, coordinateSpace: .named("reelCard"))
            .onChanged { value in
                if isInScrubberZone(value.startLocation.y) { return }
                handleSwipeChanged(deltaX: value.translation.width, deltaY: value.translation.height)
            }
            .onEnded { value in
                if isInScrubberZone(value.startLocation.y) {
                    resetSwipe()
                    return
                }
                handleSwipeEnded(deltaX: value.translation.width, deltaY: value.translation.height)
            }
    }

    func isInScrubberZone(_ posY: CGFloat) -> Bool {
        mediaBottomY > 0
            && posY >= mediaBottomY - scrubberZoneHeight
            && posY <= mediaBottomY
    }

    /// Shared swipe-progress handler. Called from both SwiftUI's DragGesture
    /// (title/details/rating-bar areas) and the UIKit pan installed on the
    /// trailer container (media area).
    func handleSwipeChanged(deltaX: CGFloat, deltaY: CGFloat) {
        let absX = abs(deltaX)
        let absY = abs(deltaY)
        guard absX > absY * 1.5 else { return }
        isDragging = true

        let maxOffset = swipeThreshold + 30
        swipeOffset = max(-maxOffset, min(maxOffset, deltaX))

        let crossed = abs(swipeOffset) >= swipeThreshold
        if crossed, !swipeTriggeredHaptic {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            swipeTriggeredHaptic = true
        } else if !crossed, swipeTriggeredHaptic {
            swipeTriggeredHaptic = false
        }
    }

    func handleSwipeEnded(deltaX: CGFloat, deltaY: CGFloat) {
        let absX = abs(deltaX)
        let absY = abs(deltaY)
        guard absX > absY * 1.5 else {
            resetSwipe()
            return
        }
        if deltaX < -swipeThreshold {
            Task { await hideMovie() }
        } else if deltaX > swipeThreshold {
            addToWatchlist()
        }
        resetSwipe()
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
        Analytics.watchlistAdded(tmdbId: movie.tmdbId, source: .reels)

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
            Analytics.movieHidden(tmdbId: movie.tmdbId)
        } catch {}
    }

    func posterURL(_ path: String) -> URL? {
        URL(
            string: "https://image.tmdb.org/t/p/w780\(path)"
        )
    }
}
