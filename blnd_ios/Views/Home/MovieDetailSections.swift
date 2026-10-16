import SwiftUI

// MARK: - UI Sections

extension MovieDetailView {
    func heroSection(_ movie: MovieResponse) -> some View {
        let trailerVideoId = movie.trailerUrl
            .flatMap { YouTubePlayerView.extractVideoId(from: $0) }
        return Group {
            if APIConfig.screenshotMode {
                heroPlaceholder
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 56, weight: .regular))
                            .foregroundStyle(.white.opacity(0.9))
                    }
            } else if let videoId = trailerVideoId {
                YouTubePlayerView(
                    videoId: videoId,
                    backdropPath: movie.backdropPath
                )
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if let backdrop = movie.backdropPath {
                CachedAsyncImage(
                    url: URL(
                        string: "https://image.tmdb.org/t/p/w780\(backdrop)"
                    )
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .posterBlur()
                        .clipShape(
                            RoundedRectangle(cornerRadius: 14)
                        )
                } placeholder: {
                    heroPlaceholder
                }
            } else {
                heroPlaceholder
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 24)
    }

    var actionButtonsRow: some View {
        HStack(spacing: 10) {
            Button { showStreamingSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Watch Now")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                )
            }

            Button { showWatchlistSheet = true } label: {
                HStack(spacing: 6) {
                    Image(
                        systemName: isInWatchlist
                            ? "bookmark.fill" : "bookmark"
                    )
                    .font(.system(size: 13, weight: .bold))
                    Text("Watchlist")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(isInWatchlist ? AppTheme.card : .white)
                .foregroundStyle(isInWatchlist ? .white : .black)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                )
            }
        }
        .padding(.bottom, 20)
        .sheet(isPresented: $showWatchlistSheet) {
            WatchlistPickerSheet(
                tmdbId: tmdbId,
                isWatched: isWatched,
                isInPersonalWatchlist: isInWatchlist
            ) { inPersonal in
                isInWatchlist = inPersonal
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
    }

    var heroPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(AppTheme.posterGradient)
            .frame(height: 200)
    }

    var detailRatingBar: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 32, height: 36)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                ForEach(1 ... 5, id: \.self) { index in
                    detailRatingStar(index: index)
                }
            }

            Spacer(minLength: 0)

            if userRating != nil {
                Button { clearDetailRating() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(width: 32, height: 36)
                }
            } else {
                Color.clear.frame(width: 32, height: 36)
            }
        }
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func detailRatingStar(index: Int) -> some View {
        let rating = userRating ?? 0
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
                .frame(width: 18, height: 32)
                .contentShape(Rectangle())
                .onTapGesture { saveDetailRating(half) }
            Color.clear
                .frame(width: 18, height: 32)
                .contentShape(Rectangle())
                .onTapGesture { saveDetailRating(full) }
        }
        .overlay {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(tint)
                .allowsHitTesting(false)
        }
    }

    private func saveDetailRating(_ value: Double) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let cache = UserActionCache.shared
        let wasWatched = isWatched
        let previousRating = userRating
        let previousWatched = isWatched
        let fromWatchlist = cache.isWatchlisted(tmdbId)
        userRating = value
        isWatched = true
        cache.didRate(tmdbId, rating: value)

        Task {
            do {
                if wasWatched {
                    _ = try await TrackingAPI.updateRating(tmdbId: tmdbId, rating: value)
                } else {
                    _ = try await TrackingAPI.trackMovie(tmdbId: tmdbId, rating: value)
                    onHide?()
                }
                Analytics.movieRated(
                    tmdbId: tmdbId,
                    rating: value,
                    source: .detail,
                    fromWatchlist: fromWatchlist,
                    isUpdate: wasWatched
                )
            } catch {
                userRating = previousRating
                isWatched = previousWatched
                if let previousRating {
                    cache.didRate(tmdbId, rating: previousRating)
                } else {
                    cache.didUnwatch(tmdbId)
                }
                reportMutation(error, screen: "RateMovie") {
                    saveDetailRating(value)
                }
            }
        }
    }

    private func clearDetailRating() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard isWatched else { return }
        let previousRating = userRating
        userRating = nil
        isWatched = false
        UserActionCache.shared.didUnwatch(tmdbId)
        Analytics.movieUnwatched(tmdbId: tmdbId, source: .detail)
        Task {
            do {
                try await TrackingAPI.deleteWatchedMovie(tmdbId: tmdbId)
            } catch {
                userRating = previousRating
                isWatched = true
                if let previousRating {
                    UserActionCache.shared.didRate(tmdbId, rating: previousRating)
                } else {
                    UserActionCache.shared.didWatch(tmdbId)
                }
                reportMutation(error, screen: "RateMovie") { clearDetailRating() }
            }
        }
    }

    func commentsRow(_ movie: MovieResponse) -> some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(AppTheme.border)
                .padding(.bottom, 12)
            Button {
                showCommentsSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textDim)
                    Text("Comments (\(movie.commentCount ?? 0))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textDim)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Data & Actions

extension MovieDetailView {
    func fetchMovie(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
            errorMessage = nil
        }
        do {
            movie = try await MoviesAPI.getMovie(tmdbId: tmdbId)
            errorMessage = nil
        } catch {
            // On a silent refresh, keep showing the existing movie rather than
            // replacing it with a full-screen error.
            if movie == nil {
                errorMessage = UserFacingError.capture(error, screen: "MovieDetail")
            }
        }
        if showLoading {
            isLoading = false
        }
    }

    /// Pull-to-refresh: reloads the movie (incl. comment count), watched/rating,
    /// hidden, and friends state without flashing the loading spinner.
    func refreshAll() async {
        async let movie: () = fetchMovie(showLoading: false)
        async let watched: () = checkWatchedStatus()
        async let hidden: () = checkHiddenStatus()
        async let friends: () = loadFriendsWhoWatched()
        _ = await (movie, watched, hidden, friends)
    }

    func checkWatchedStatus() async {
        let cache = UserActionCache.shared
        if cache.isWatched(tmdbId) {
            isWatched = true
            userRating = cache.rating(for: tmdbId)
        } else if let watched = try? await TrackingAPI.getWatchedMovie(tmdbId: tmdbId) {
            isWatched = true
            userRating = watched.rating
            if let rating = watched.rating {
                cache.didRate(tmdbId, rating: rating)
            } else {
                cache.didWatch(tmdbId)
            }
        }
    }

    func loadFriendsWhoWatched() async {
        do {
            let response = try await TrackingAPI.friendsWhoWatched(
                tmdbId: tmdbId
            )
            friendsWhoWatched = response.results
        } catch { /* Non-critical — friends section stays hidden */ }
    }

    func checkHiddenStatus() async {
        do {
            let response = try await RecommendationsAPI.getHidden()
            isHidden = response.results.contains {
                $0.tmdbId == tmdbId
            }
        } catch {
            // Default to not hidden
        }
    }

    func hideMovie() async {
        let wasHidden = isHidden
        isHidden = true
        do {
            _ = try await RecommendationsAPI.hideMovie(
                tmdbId: tmdbId
            )
            onHide?()
        } catch {
            isHidden = wasHidden
            reportMutation(error, screen: "HideMovie") { await hideMovie() }
        }
    }

    func unhideMovie() async {
        let wasHidden = isHidden
        isHidden = false
        do {
            try await RecommendationsAPI.unhideMovie(
                tmdbId: tmdbId
            )
        } catch {
            isHidden = wasHidden
            reportMutation(error, screen: "UnhideMovie") { await unhideMovie() }
        }
    }

    func reportMutation(
        _ error: Error,
        screen: String,
        retry: @escaping () async -> Void
    ) {
        actionToast = UserFacingError.capture(error, screen: screen)
        actionRetry = { Task { await retry() } }
    }
}
