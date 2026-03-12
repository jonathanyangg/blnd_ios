import SwiftUI

struct MovieDetailView: View {
    let tmdbId: Int
    var title: String = ""
    var onHide: (() -> Void)?

    @State var movie: MovieResponse?
    @State var isLoading = true
    @State var errorMessage: String?
    @State var showRatingSheet = false
    @State var isInWatchlist = false
    @State var isWatched = false
    @State var userRating: Double?
    @State var isWatchlistLoading = false
    @State var showUnwatchConfirm = false
    @State var showWatchlistSheet = false
    @State var friendsWhoWatched: [FriendWatchedResponse] = []
    @State var isHidden = false
    @State var showHideConfirm = false

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
            ToolbarItem(placement: .principal) {
                if let pct = movie?.matchPercent {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("\(pct)% match")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.card)
                    .clipShape(Capsule())
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if isHidden {
                        Task { await unhideMovie() }
                    } else {
                        showHideConfirm = true
                    }
                } label: {
                    Image(
                        systemName: isHidden
                            ? "hand.thumbsdown.fill"
                            : "hand.thumbsdown"
                    )
                    .font(.system(size: 16))
                    .foregroundStyle(
                        isHidden ? .red : AppTheme.textMuted
                    )
                }
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
        .confirmationDialog(
            "Not interested?",
            isPresented: $showHideConfirm,
            titleVisibility: .visible
        ) {
            Button("Not for me", role: .destructive) {
                Task { await hideMovie() }
            }
        } message: {
            Text("This movie won't show in your recommendations.")
        }
        .task {
            await fetchMovie()
            async let watched: () = checkWatchedStatus()
            async let hidden: () = checkHiddenStatus()
            async let friends: () = loadFriendsWhoWatched()
            _ = await (watched, hidden, friends)
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

    private func detailSection(_ movie: MovieResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(movie.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 16)

            metaRow(movie)
            genreRow(movie)
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
}
