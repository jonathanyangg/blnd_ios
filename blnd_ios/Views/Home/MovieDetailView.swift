import SwiftUI

struct MovieDetailView: View {
    let tmdbId: Int
    var title: String = ""

    @State private var movie: MovieResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showRatingSheet = false
    @State private var isInWatchlist = false
    @State private var isWatched = false
    @State private var userRating: Double?
    @State private var isWatchlistLoading = false
    @State private var showUnwatchConfirm = false
    @State private var showWatchlistSheet = false
    @State private var friendsWhoWatched: [FriendWatchedResponse] = []

    private var displayTitle: String {
        movie?.title ?? title
    }

    private var displayYear: String {
        movie?.yearString ?? ""
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await fetchMovie() }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else if let movie {
                movieContent(movie)
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .sheet(isPresented: $showRatingSheet) {
            RateMovieSheet(
                title: displayTitle,
                year: displayYear,
                tmdbId: tmdbId,
                posterPath: movie?.posterPath,
                existingRating: isWatched ? userRating : nil,
                onSaved: { savedRating in
                    isWatched = true
                    userRating = savedRating
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
        .task {
            await fetchMovie()
            async let watched: () = checkWatchedStatus()
            async let friends: () = loadFriendsWhoWatched()
            _ = await (watched, friends)
        }
    }

    // MARK: - Movie Content

    private func movieContent(_ movie: MovieResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            heroSection(movie)
            detailSection(movie)
        }
        .padding(.bottom, 32)
    }

    private func heroSection(_ movie: MovieResponse) -> some View {
        ZStack {
            if let backdrop = movie.backdropPath {
                AsyncImage(
                    url: URL(string: "https://image.tmdb.org/t/p/w780\(backdrop)")
                ) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }

            if let trailerUrl = movie.trailerUrl, let url = URL(string: trailerUrl) {
                Link(destination: url) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 24)
    }

    private func detailSection(_ movie: MovieResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(movie.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 16)

            metaRow(movie)
            genreRow(movie)
            matchScoreBadge(movie)
            ratingSection(movie)
            overviewSection(movie)
            actionButtons
            FriendsWhoWatchedSection(friends: friendsWhoWatched)
            CastSectionView(cast: movie.cast)
        }
        .padding(.horizontal, 24)
    }

    private func metaRow(_ movie: MovieResponse) -> some View {
        var parts = [movie.yearString, movie.runtimeFormatted]
            .compactMap { $0?.isEmpty == true ? nil : $0 }
        if let vote = movie.voteAverage, vote > 0 {
            parts.append("★ \(String(format: "%.1f", vote))")
        }
        let meta = parts.joined(separator: " \u{00B7} ")
        return Group {
            if !meta.isEmpty {
                Text(meta)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
            }
        }
    }

    @ViewBuilder
    private func genreRow(_ movie: MovieResponse) -> some View {
        if !movie.genres.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(movie.genres.filter { $0.name != nil }) { genre in
                        GenrePill(label: genre.name ?? "", isSmall: true)
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func matchScoreBadge(_ movie: MovieResponse) -> some View {
        if let pct = movie.matchPercent {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                Text("\(pct)% match for you")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppTheme.card)
            .clipShape(Capsule())
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private func ratingSection(_ movie: MovieResponse) -> some View {
        HStack(spacing: 4) {
            if let userRating {
                StarRatingDisplay(rating: userRating)
            } else {
                StarRatingDisplay(rating: 0)
                Text("Rate")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textDim)
            }
        }
        .padding(.bottom, 8)
        .onTapGesture {
            showRatingSheet = true
        }

        if let tagline = movie.tagline, !tagline.isEmpty {
            Text(tagline)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .italic()
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func overviewSection(_ movie: MovieResponse) -> some View {
        if let overview = movie.overview, !overview.isEmpty {
            Text(overview)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .lineSpacing(4)
                .padding(.bottom, 16)
        }

        if let director = movie.director {
            HStack(spacing: 4) {
                Text("Directed by")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textDim)
                Text(director)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 16)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                if isWatched {
                    showUnwatchConfirm = true
                } else {
                    showRatingSheet = true
                }
            } label: {
                HStack(spacing: 6) {
                    if isWatched {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text("Watched")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(isWatched ? .white : AppTheme.card)
                .foregroundStyle(isWatched ? .black : .white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }

            Button { showWatchlistSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Watchlist")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(isInWatchlist ? AppTheme.card : .white)
                .foregroundStyle(isInWatchlist ? .white : .black)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
        }
        .padding(.bottom, 20)
        .confirmationDialog(
            "Remove from watched?",
            isPresented: $showUnwatchConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task { await unwatchMovie() }
            }
        } message: {
            Text("This will remove your rating and watch history for this movie.")
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

    // MARK: - Helpers

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
        if let watched = await TrackingAPI.getWatchedMovie(tmdbId: tmdbId) {
            isWatched = true
            userRating = watched.rating
        }
    }

    func unwatchMovie() async {
        do {
            try await TrackingAPI.deleteWatchedMovie(tmdbId: tmdbId)
            isWatched = false
            userRating = nil
        } catch {
            print("[MovieDetailView] unwatch error: \(error)")
        }
    }

    func loadFriendsWhoWatched() async {
        do {
            let response = try await TrackingAPI.friendsWhoWatched(tmdbId: tmdbId)
            friendsWhoWatched = response.results
        } catch {
            print("[MovieDetailView] friends who watched error: \(error)")
        }
    }

    func toggleWatchlist() async {
        isWatchlistLoading = true
        do {
            if isInWatchlist {
                try await TrackingAPI.removeFromWatchlist(tmdbId: tmdbId)
                isInWatchlist = false
            } else {
                _ = try await TrackingAPI.addToWatchlist(tmdbId: tmdbId)
                isInWatchlist = true
            }
        } catch {
            print("[MovieDetailView] watchlist toggle error: \(error)")
        }
        isWatchlistLoading = false
    }
}
