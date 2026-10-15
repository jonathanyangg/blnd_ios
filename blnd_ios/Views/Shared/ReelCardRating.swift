import SwiftUI

// MARK: - Inline Rating Bar

extension ReelCardView {
    var currentUserRating: Double? {
        UserActionCache.shared.rating(for: movie.tmdbId)
    }

    var watchedWithButton: some View {
        Button {
            showLogSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.2")
                Text("Watched with")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var inlineRatingBar: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 32, height: 36)

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                ForEach(1 ... 5, id: \.self) { index in
                    ratingStar(index: index)
                }
            }

            Spacer(minLength: 0)

            if currentUserRating != nil {
                Button { clearRating() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(width: 32, height: 36)
                }
            } else {
                Color.clear.frame(width: 32, height: 36)
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func ratingStar(index: Int) -> some View {
        let rating = currentUserRating ?? 0
        let full = Double(index)
        let half = full - 0.5
        let icon = if rating >= full {
            "star.fill"
        } else if rating >= half {
            "star.leadinghalf.filled"
        } else {
            "star"
        }
        let tint: Color = rating >= half ? .white : AppTheme.border

        HStack(spacing: 0) {
            Color.clear
                .frame(width: 18, height: 36)
                .contentShape(Rectangle())
                .onTapGesture { saveRating(half) }
            Color.clear
                .frame(width: 18, height: 36)
                .contentShape(Rectangle())
                .onTapGesture { saveRating(full) }
        }
        .overlay {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(tint)
                .allowsHitTesting(false)
        }
    }

    private func saveRating(_ value: Double) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let cache = UserActionCache.shared
        let wasWatched = cache.isWatched(movie.tmdbId)
        let fromWatchlist = cache.isWatchlisted(movie.tmdbId)
        cache.didRate(movie.tmdbId, rating: value)

        Task {
            do {
                if wasWatched {
                    _ = try await TrackingAPI.updateRating(tmdbId: movie.tmdbId, rating: value)
                } else {
                    _ = try await TrackingAPI.trackMovie(tmdbId: movie.tmdbId, rating: value)
                }
                Analytics.movieRated(
                    tmdbId: movie.tmdbId,
                    rating: value,
                    source: .reels,
                    fromWatchlist: fromWatchlist,
                    isUpdate: wasWatched
                )
            } catch {
                // Non-critical — cache stays updated; user can retry
            }
        }

        onRated?(value)
    }

    private func clearRating() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let cache = UserActionCache.shared
        guard cache.isWatched(movie.tmdbId) else { return }
        cache.didUnwatch(movie.tmdbId)
        Analytics.movieUnwatched(tmdbId: movie.tmdbId, source: .reels)
        Task {
            try? await TrackingAPI.deleteWatchedMovie(tmdbId: movie.tmdbId)
        }
    }
}
