import SwiftUI

enum ReelSwipeResult {
    case hidden
    case interested
    case interestFailed
    case notForMeFailed
}

enum ReelSwipeDecision: Equatable {
    case notForMe
    case interested
    case ignore
}

/// Horizontal swipe past the threshold. Right is a taste signal, never a watchlist add.
func reelSwipeDecision(
    deltaX: CGFloat,
    deltaY: CGFloat,
    threshold: CGFloat
) -> ReelSwipeDecision {
    guard abs(deltaX) > abs(deltaY) * 1.5 else { return .ignore }
    if deltaX < -threshold { return .notForMe }
    if deltaX > threshold { return .interested }
    return .ignore
}

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
        switch reelSwipeDecision(
            deltaX: deltaX,
            deltaY: deltaY,
            threshold: swipeThreshold
        ) {
        case .notForMe:
            Task { await markNotForMe() }
        case .interested:
            Task { await markInterested() }
        case .ignore:
            break
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

    /// Positive taste signal only. Watchlist adds go through the card button.
    func markInterested() async {
        if APIConfig.screenshotMode {
            onSwipeResult?(.interested)
            return
        }
        do {
            try await RecommendationsAPI.markInterested(
                tmdbId: movie.tmdbId
            )
            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)
            Analytics.movieInterested(tmdbId: movie.tmdbId)
            onSwipeResult?(.interested)
        } catch {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)
            onSwipeResult?(.interestFailed)
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

    /// Left swipe. A weak negative signal, not a watchlist change and not a hide.
    func markNotForMe() async {
        do {
            try await RecommendationsAPI.markNotForMe(tmdbId: movie.tmdbId)
            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)
            Analytics.movieHidden(tmdbId: movie.tmdbId)
            onSwipeResult?(.hidden)
        } catch {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)
            onSwipeResult?(.notForMeFailed)
        }
    }

    func posterURL(_ path: String) -> URL? {
        URL(
            string: "https://image.tmdb.org/t/p/w780\(path)"
        )
    }
}
