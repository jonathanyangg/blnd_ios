import SwiftUI

struct MovieDetailView: View {
    let tmdbId: Int
    var title: String = ""
    var source: Analytics.DetailSource = .grid
    var onHide: (() -> Void)?

    @State var movie: MovieResponse?
    @State var isLoading = true
    @State var errorMessage: UserFacingError?
    @State var actionToast: UserFacingError?
    @State var actionRetry: (() -> Void)?
    @State var isInWatchlist = false
    @State var isWatched = false
    @State var userRating: Double?
    @State var showWatchlistSheet = false
    @State var friendsWhoWatched: [FriendWatchedResponse] = []
    @State var isHidden = false
    @State var showHideConfirm = false
    @State var showStreamingSheet = false
    @State var showCommentsSheet = false
    @State var overviewExpanded = false

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
                ErrorStateView(message: error) {
                    Task { await fetchMovie() }
                }
                .padding(.top, 100)
            } else if let movie {
                movieContent(movie)
            }
        }
        .refreshable {
            await refreshAll()
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if isHidden {
                        Task { await unhideMovie() }
                    } else {
                        showHideConfirm = true
                    }
                } label: {
                    Image(systemName: isHidden ? "eye.slash.fill" : "eye.slash")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .accessibilityLabel(isHidden ? "Hidden" : "Not for me")
                .confirmationDialog(
                    "Not for me?",
                    isPresented: $showHideConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Not for me") {
                        Task { await hideMovie() }
                    }
                } message: {
                    Text(
                        "This movie won't show in your recommendations."
                    )
                }
            }
        }
        .sheet(isPresented: $showStreamingSheet) {
            StreamingSheet(tmdbId: tmdbId, title: displayTitle)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.card)
        }
        .sheet(isPresented: $showCommentsSheet) {
            MovieCommentsView(tmdbId: tmdbId, movieTitle: displayTitle)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.card)
        }
        .overlay(alignment: .top) {
            if let actionToast {
                ErrorToast(message: actionToast, retry: actionRetry, onDismiss: {
                    self.actionToast = nil
                    actionRetry = nil
                })
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
        }
        .task {
            Analytics.movieDetailViewed(tmdbId: tmdbId, source: source)
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
            HStack(alignment: .center, spacing: 10) {
                Text(
                    APIConfig.screenshotMode
                        ? ScreenshotDummy.title(for: movie.tmdbId)
                        : movie.title
                )
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

                let displayPct = APIConfig.screenshotMode
                    ? ScreenshotDummy.matchPercent(for: movie.tmdbId)
                    : movie.matchPercent
                if let pct = displayPct {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(
                                AppTheme.aiPurple
                            )
                        Text("\(pct)% match")
                            .font(.system(
                                size: 13, weight: .bold
                            ))
                            .foregroundStyle(
                                AppTheme.aiGradient
                            )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        AppTheme.aiPurple.opacity(0.12)
                    )
                    .clipShape(Capsule())
                }
            }
            .padding(.top, 16)

            metaRow(movie)
            genreRow(movie)
            taglineSection(movie)
            overviewSection(movie)
            CastSectionView(cast: movie.cast)

            Divider()
                .overlay(AppTheme.border)
                .padding(.bottom, 20)

            detailRatingBar
            actionButtonsRow
            FriendsWhoWatchedSection(friends: friendsWhoWatched)
            commentsRow(movie)
        }
        .padding(.horizontal, 24)
    }

    private func metaRow(_ movie: MovieResponse) -> some View {
        let parts: [String]
        if APIConfig.screenshotMode {
            let tid = movie.tmdbId
            let runtime = ScreenshotDummy.runtime(for: tid)
            let hours = runtime / 60
            let minutes = runtime % 60
            let runtimeStr = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            let vote = ScreenshotDummy.voteAverage(for: tid)
            parts = [
                "\(ScreenshotDummy.year(for: tid))",
                runtimeStr,
                "★ \(String(format: "%.1f", vote))",
                ScreenshotDummy.director(for: tid),
            ]
        } else {
            var result = [movie.yearString, movie.runtimeFormatted]
                .compactMap { $0?.isEmpty == true ? nil : $0 }
            if let vote = movie.voteAverage, vote > 0 {
                result.append("★ \(String(format: "%.1f", vote))")
            }
            if let director = movie.director {
                result.append(director)
            }
            parts = result
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
    private func taglineSection(_ movie: MovieResponse) -> some View {
        let tagline = APIConfig.screenshotMode
            ? ScreenshotDummy.tagline(for: movie.tmdbId)
            : (movie.tagline ?? "")
        if !tagline.isEmpty {
            Text(tagline)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .italic()
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func overviewSection(_ movie: MovieResponse) -> some View {
        let overview = APIConfig.screenshotMode
            ? ScreenshotDummy.overview(for: movie.tmdbId)
            : (movie.overview ?? "")
        if !overview.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(overview)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineSpacing(4)
                    .lineLimit(overviewExpanded ? nil : 2)

                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            overviewExpanded.toggle()
                        }
                    } label: {
                        Text(overviewExpanded ? "less" : "more")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }
}
