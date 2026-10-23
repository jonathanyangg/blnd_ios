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

    var whereToWatchSection: some View {
        WhereToWatchSection(
            payload: whereToWatch,
            isLoading: watchLoading,
            failed: watchFailed,
            isPremium: authState.isPremium
        ) { offer, kind in
            PendingWatchStore().opened(tmdbId: tmdbId, title: displayTitle, posterPath: movie?.posterPath)
            Task { await WatchLinkOpener.open(offer, kind: kind) }
        }
        .padding([.horizontal, .top], 14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch.hub")
    }

    /// Watchlist toggle and Watched (marks it, then opens the rate/log sheet).
    var actionBar: some View {
        HStack(spacing: 10) {
            actionButton(
                icon: isInWatchlist ? "bookmark.fill" : "bookmark",
                label: "Watchlist",
                isOn: isInWatchlist
            ) { toggleWatchlist() }
                .accessibilityIdentifier("detail.watchlist")
                .contextMenu {
                    Button("Add to a blend watchlist") { showWatchlistSheet = true }
                }
            actionButton(
                icon: isWatched ? "eye.fill" : "eye",
                label: "Watched",
                isOn: isWatched
            ) { markWatched() }
                .accessibilityIdentifier("detail.watched")
        }
        .padding(.bottom, 16)
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
        .sheet(isPresented: $showLogSheet) {
            RateMovieSheet(
                title: movie?.title ?? title,
                year: movie?.yearString ?? "",
                tmdbId: tmdbId,
                posterPath: movie?.posterPath,
                existingRating: userRating
            ) { newRating in
                userRating = newRating
                isWatched = true
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
    }

    private func actionButton(
        icon: String,
        label: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(label)
            }
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(isOn ? AppTheme.card : .white)
            .foregroundStyle(isOn ? .white : .black)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func toggleWatchlist() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let adding = !isInWatchlist
        isInWatchlist = adding
        if adding {
            UserActionCache.shared.didWatchlist(tmdbId)
        } else {
            UserActionCache.shared.didRemoveFromWatchlist(tmdbId)
        }
        Task {
            do {
                if adding {
                    _ = try await TrackingAPI.addToWatchlist(tmdbId: tmdbId)
                } else {
                    try await TrackingAPI.removeFromWatchlist(tmdbId: tmdbId)
                }
            } catch {
                isInWatchlist = !adding
                if adding {
                    UserActionCache.shared.didRemoveFromWatchlist(tmdbId)
                } else {
                    UserActionCache.shared.didWatchlist(tmdbId)
                }
                reportMutation(error, screen: "Watchlist") { toggleWatchlist() }
            }
        }
    }

    private func markWatched() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showLogSheet = true
        guard !isWatched else { return }
        isWatched = true
        UserActionCache.shared.didWatch(tmdbId)
        Task {
            do {
                _ = try await TrackingAPI.trackMovie(tmdbId: tmdbId)
                onHide?()
            } catch {
                isWatched = false
                UserActionCache.shared.didUnwatch(tmdbId)
                reportMutation(error, screen: "MarkWatched") { markWatched() }
            }
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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("detail.rate")

            Spacer(minLength: 0)

            if userRating != nil {
                Button { clearDetailRating() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(width: 32, height: 36)
                }
                .accessibilityLabel("Clear rating")
                .accessibilityIdentifier("detail.rate.clear")
            } else {
                Color.clear.frame(width: 32, height: 36)
            }
        }
        .padding(.bottom, 12)
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
        if mediaType == .tv {
            await loadWhereToWatch(showLoading: false)
            return
        }
        async let movie: () = fetchMovie(showLoading: false)
        async let watch: () = loadWhereToWatch(showLoading: false)
        async let watched: () = checkWatchedStatus()
        async let hidden: () = checkHiddenStatus()
        async let friends: () = loadFriendsWhoWatched()
        _ = await (movie, watch, watched, hidden, friends)
    }

    /// `showLoading` is false on pull-to-refresh so a failure keeps the offers
    /// already on screen.
    func loadWhereToWatch(showLoading: Bool = true) async {
        if showLoading {
            watchLoading = true
            watchFailed = false
        }
        defer { watchLoading = false }
        let type = mediaType ?? movie?.mediaType ?? .movie
        do {
            let response = try await MoviesAPI.getStreaming(
                tmdbId: tmdbId,
                mediaType: type
            )
            whereToWatch = response.whereToWatch
            watchFailed = response.whereToWatch == nil
        } catch is CancellationError {
            return
        } catch {
            guard whereToWatch == nil else { return }
            whereToWatch = nil
            watchFailed = true
        }
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

    func checkWatchlistStatus() async {
        isInWatchlist = UserActionCache.shared.isWatchlisted(tmdbId)
        if let status = try? await TrackingAPI.getWatchlistStatus(tmdbId: tmdbId) {
            isInWatchlist = status.personal
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
