import SwiftUI

// MARK: - UI Sections

extension MovieDetailView {
    func heroSection(_ movie: MovieResponse) -> some View {
        Group {
            if let trailerUrl = movie.trailerUrl, let videoId = YouTubePlayerView.extractVideoId(from: trailerUrl) {
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

    var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                if isWatched {
                    showWatchedOptions = true
                } else {
                    showRatingSheet = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(
                        systemName: isWatched
                            ? "checkmark.circle.fill" : "eye"
                    )
                    .font(.system(size: 14, weight: .semibold))
                    if isWatched {
                        if let userRating {
                            Text("★ \(String(format: "%.1f", userRating))")
                        } else {
                            Text("Watched")
                        }
                    } else {
                        Text("Mark Watched")
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(isWatched ? .white : AppTheme.card)
                .foregroundStyle(isWatched ? .black : .white)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: AppTheme.cornerRadiusMedium
                    )
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
                .background(
                    isInWatchlist ? AppTheme.card : .white
                )
                .foregroundStyle(
                    isInWatchlist ? .white : .black
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: AppTheme.cornerRadiusMedium
                    )
                )
            }
        }
        .padding(.bottom, 20)
        .confirmationDialog(
            "Watched",
            isPresented: $showWatchedOptions,
            titleVisibility: .visible
        ) {
            Button("Change Rating") {
                showRatingSheet = true
            }
            Button(
                "Remove from Watched",
                role: .destructive
            ) {
                showUnwatchConfirm = true
            }
        }
        .confirmationDialog(
            "Remove from watched?",
            isPresented: $showUnwatchConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task { await unwatchMovie() }
            }
        } message: {
            Text(
                "This will remove your rating and watch "
                    + "history for this movie."
            )
        }
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
}

// MARK: - Data & Actions

extension MovieDetailView {
    func fetchMovie() async {
        isLoading = true
        errorMessage = nil
        do {
            movie = try await MoviesAPI.getMovie(tmdbId: tmdbId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func checkWatchedStatus() async {
        let cache = UserActionCache.shared
        if cache.isWatched(tmdbId) {
            isWatched = true
            userRating = cache.rating(for: tmdbId)
        } else if let watched = await TrackingAPI.getWatchedMovie(tmdbId: tmdbId) {
            isWatched = true
            userRating = watched.rating
            cache.didRate(tmdbId, rating: watched.rating ?? 0)
        }
    }

    func unwatchMovie() async {
        do {
            try await TrackingAPI.deleteWatchedMovie(tmdbId: tmdbId)
            isWatched = false
            userRating = nil
            UserActionCache.shared.didUnwatch(tmdbId)
        } catch {
            print("[MovieDetailView] unwatch error: \(error)")
        }
    }

    func loadFriendsWhoWatched() async {
        do {
            let response = try await TrackingAPI.friendsWhoWatched(
                tmdbId: tmdbId
            )
            friendsWhoWatched = response.results
        } catch {
            print(
                "[MovieDetailView] friends who watched error: "
                    + "\(error)"
            )
        }
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
        do {
            _ = try await RecommendationsAPI.hideMovie(
                tmdbId: tmdbId
            )
            isHidden = true
            onHide?()
        } catch {
            print("[MovieDetailView] hide error: \(error)")
        }
    }

    func unhideMovie() async {
        do {
            try await RecommendationsAPI.unhideMovie(
                tmdbId: tmdbId
            )
            isHidden = false
        } catch {
            print("[MovieDetailView] unhide error: \(error)")
        }
    }

    func toggleWatchlist() async {
        isWatchlistLoading = true
        do {
            if isInWatchlist {
                try await TrackingAPI.removeFromWatchlist(
                    tmdbId: tmdbId
                )
                isInWatchlist = false
            } else {
                _ = try await TrackingAPI.addToWatchlist(
                    tmdbId: tmdbId
                )
                isInWatchlist = true
            }
        } catch {
            print(
                "[MovieDetailView] watchlist toggle error: \(error)"
            )
        }
        isWatchlistLoading = false
    }
}
