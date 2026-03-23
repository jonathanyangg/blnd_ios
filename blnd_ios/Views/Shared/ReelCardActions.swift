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
                swipeOffset = value.translation.width

                let crossed = abs(swipeOffset) >= swipeThreshold
                if crossed, !swipeTriggeredHaptic {
                    let haptic = UIImpactFeedbackGenerator(
                        style: .medium
                    )
                    haptic.impactOccurred()
                    swipeTriggeredHaptic = true
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
                    addToWatchlist()
                } else if off > swipeThreshold {
                    showRating = true
                }
                resetSwipe()
            }
    }

    func resetSwipe() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            swipeOffset = 0
        }
        swipeTriggeredHaptic = false
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.15
        ) {
            isDragging = false
        }
    }

    func addToWatchlist() {
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

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

    func posterURL(_ path: String) -> URL? {
        URL(
            string: "https://image.tmdb.org/t/p/w780\(path)"
        )
    }
}
