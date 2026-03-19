import SwiftUI

// MARK: - Gestures & Actions

extension ReelCardView {
    func handleTap() {
        guard !isDragging else { return }
        onNavigateToDetail?(movie.tmdbId, movie.title)
    }

    var horizontalSwipe: some Gesture {
        DragGesture(minimumDistance: 25)
            .updating($dragOffset) { value, state, _ in
                let dxx = abs(value.translation.width)
                let dyy = abs(value.translation.height)
                if dxx > dyy * 1.5 {
                    state = value.translation.width
                    isDragging = true
                }
            }
            .onEnded { value in
                let dxx = abs(value.translation.width)
                let dyy = abs(value.translation.height)
                guard dxx > dyy * 1.5 else {
                    isDragging = false
                    return
                }
                let off = value.translation.width
                if off < -swipeThreshold {
                    addToWatchlist()
                } else if off > swipeThreshold {
                    showRating = true
                }
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.15
                ) {
                    isDragging = false
                }
            }
    }

    func addToWatchlist() {
        let haptic = UIImpactFeedbackGenerator(
            style: .medium
        )
        haptic.impactOccurred()

        Task {
            do {
                if let ctx = groupContext {
                    _ = try await GroupsAPI.addToWatchlist(
                        groupId: ctx.groupId,
                        tmdbId: movie.tmdbId
                    )
                    onWatchlistAdded?(
                        "Added to \(ctx.groupName) Watchlist"
                    )
                } else {
                    _ = try await TrackingAPI.addToWatchlist(
                        tmdbId: movie.tmdbId
                    )
                    onWatchlistAdded?(
                        "Added to My Watchlist"
                    )
                }
            } catch {
                // Already in watchlist or other error
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
