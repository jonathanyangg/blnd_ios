import SwiftUI

// MARK: - View Sections

extension ReelCardView {
    // MARK: - Title

    var displayTitle: String {
        APIConfig.screenshotMode
            ? ScreenshotDummy.title(for: movie.tmdbId)
            : movie.title
    }

    var displayScorePercent: Int? {
        if APIConfig.screenshotMode {
            return ScreenshotDummy.matchPercent(for: movie.tmdbId)
        }
        return movie.scorePercent
    }

    var titleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(displayTitle)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            if let pct = displayScorePercent {
                Text("\(pct)% match")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
    }

    /// Primary CTA — opens the where-to-watch streaming sheet.
    var watchNowButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.fill")
                .font(.system(size: 14))
            Text("Watch Now")
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded { showStreamingSheet = true }
        )
        .accessibilityIdentifier("reel.watchNow")
        .reelTutorialFrame(.watchNow, active: isActive)
    }

    var metaLine: some View {
        Group {
            let meta = metaParts.joined(
                separator: " \u{00B7} "
            )
            if !meta.isEmpty {
                Text(meta)
            }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white.opacity(0.75))
        .lineLimit(1)
    }

    var metaParts: [String] {
        if APIConfig.screenshotMode {
            let tid = movie.tmdbId
            let runtime = ScreenshotDummy.runtime(for: tid)
            let hours = runtime / 60
            let minutes = runtime % 60
            let runtimeStr = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            let vote = ScreenshotDummy.voteAverage(for: tid)
            return [
                "\(ScreenshotDummy.year(for: tid))",
                runtimeStr,
                "★ \(String(format: "%.1f", vote))",
                ScreenshotDummy.director(for: tid),
            ]
        }
        var parts: [String] = []
        if !movie.yearString.isEmpty {
            parts.append(movie.yearString)
        }
        if let runtime = movie.runtimeFormatted {
            parts.append(runtime)
        }
        if let vote = movie.voteAverage, vote > 0 {
            parts.append("★ \(String(format: "%.1f", vote))")
        }
        if let director = movie.director {
            parts.append(director)
        }
        return parts
    }

    // MARK: - Media

    /// Full-bleed poster. The 16:9 trailer sits on top of this instead of in a black gap.
    var posterBackground: some View {
        ZStack {
            AppTheme.posterGradient
            if !APIConfig.screenshotMode, let path = movie.posterPath ?? movie.backdropPath, let url = posterURL(path) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .posterBlur()
                } placeholder: {
                    AppTheme.posterGradient
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
    }

    /// Trailer stays 16:9. Touches pass through so a vertical drag scrolls the feed.
    @ViewBuilder
    var trailerOverlay: some View {
        if showTrailer, let videoId = trailerVideoId {
            VStack(spacing: 0) {
                ReelTrailerView(videoId: videoId)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .padding(.top, 8)
                    .background(GeometryReader { geo in
                        Color.clear.preference(
                            key: MediaBottomYKey.self,
                            value: geo.frame(in: .named("reelCard")).maxY
                        )
                    })
                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)
        }
    }

    var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.32),
                .init(color: .black.opacity(0.45), location: 0.58),
                .init(color: .black.opacity(0.88), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    var genreLine: some View {
        Text(genres.prefix(3).compactMap(\.name).joined(separator: "  ·  "))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            .lineLimit(1)
    }

    // MARK: - Details

    var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !genres.isEmpty {
                genrePills
                    .layoutPriority(3)
            }

            cardTagline
                .layoutPriority(2)
        }
    }

    // MARK: - Watched By (compact row → modal)

    @ViewBuilder
    var watchedByRow: some View {
        if !friendsWhoWatched.isEmpty {
            HStack(spacing: 10) {
                Text("Watched by")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))

                overlappingAvatars

                if friendsWhoWatched.count > 5 {
                    Text("+\(friendsWhoWatched.count - 5)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textDim)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded { showWatchedBySheet = true }
            )
        }
    }

    private var overlappingAvatars: some View {
        HStack(spacing: 0) {
            ForEach(
                Array(friendsWhoWatched.prefix(5).enumerated()),
                id: \.element.id
            ) { idx, friend in
                AvatarView(url: friend.avatarUrl, size: 26, overlap: idx > 0)
            }
        }
    }

    // MARK: - Tagline

    @ViewBuilder
    var cardTagline: some View {
        let realTagline = movie.tagline ?? ""
        let tagline = APIConfig.screenshotMode
            ? ScreenshotDummy.tagline(for: movie.tmdbId)
            : realTagline
        if !tagline.isEmpty {
            Text(tagline)
                .font(.system(
                    size: 13, weight: .medium
                ))
                .foregroundStyle(.white.opacity(0.7))
                .italic()
                .lineLimit(2)
        }
    }

    // MARK: - Compact Cast

    @ViewBuilder
    var compactCastSection: some View {
        if !movie.cast.isEmpty {
            ScrollView(
                .horizontal, showsIndicators: false
            ) {
                HStack(spacing: 10) {
                    ForEach(
                        Array(
                            movie.cast.prefix(5)
                                .enumerated()
                        ),
                        id: \.element.stableId
                    ) { idx, member in
                        Button {
                            selectedCastMember = member
                        } label: {
                            VStack(spacing: 3) {
                                castAvatar(member)
                                Text(
                                    APIConfig.screenshotMode
                                        ? ScreenshotDummy.castName(at: idx)
                                        : member.name
                                )
                                .font(.system(size: 9))
                                .foregroundStyle(
                                    AppTheme.textMuted
                                )
                                .lineLimit(1)
                                .frame(width: 36)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func castAvatar(
        _ member: CastMember
    ) -> some View {
        let base = "https://image.tmdb.org/t/p/w185"
        Group {
            if let path = member.profilePath, let url = URL(string: "\(base)\(path)") {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.card)
                }
            } else {
                Circle()
                    .fill(AppTheme.card)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    // MARK: - Genre Pills

    var genrePills: some View {
        HStack(spacing: 6) {
            ForEach(genres.prefix(4)) { genre in
                Text(genre.name ?? "")
                    .font(.system(
                        size: 11,
                        weight: .medium
                    ))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(AppTheme.card)
                    .foregroundStyle(
                        AppTheme.textMuted
                    )
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    // MARK: - Watchlist Button

    var watchlistButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "bookmark")
                .font(.system(size: 13))
            Text("Add to watchlist")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                onRequestWatchlist?()
            }
        )
        .accessibilityIdentifier("reel.watchlist")
        .reelTutorialFrame(.watchlist, active: isActive)
    }

    // MARK: - Comments Button

    var commentsButton: some View {
        HStack(spacing: 6) {
            Text("Comments")
                .font(.system(size: 14, weight: .medium))
            Image(systemName: "bubble.left")
                .font(.system(size: 13))
            if let count = movie.commentCount, count > 0 {
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textDim)
            }
            Spacer()
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                showCommentsSheet = true
            }
        )
    }

    // MARK: - Swipe Indicators

    @ViewBuilder
    var swipeIndicators: some View {
        if swipeOffset < -15 {
            HStack {
                Spacer()
                ReelSwipeIndicator(offset: swipeOffset, threshold: swipeThreshold, isLeft: true)
                    .padding(.trailing, 40)
            }
        }
        if swipeOffset > 15 {
            HStack {
                ReelSwipeIndicator(offset: swipeOffset, threshold: swipeThreshold, isLeft: false)
                    .padding(.leading, 40)
                Spacer()
            }
        }
    }
}
