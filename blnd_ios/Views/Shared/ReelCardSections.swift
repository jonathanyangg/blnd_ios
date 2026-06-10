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
        HStack(alignment: .center, spacing: 8) {
            Text(displayTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)

            if let pct = displayScorePercent {
                matchBadge(pct)
            }

            Spacer()
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
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded { showStreamingSheet = true }
        )
    }

    func matchBadge(_ pct: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.aiPurple)
            Text("\(pct)% match")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.aiGradient)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.aiPurple.opacity(0.12))
        .clipShape(Capsule())
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
        .font(.system(size: 14))
        .foregroundStyle(AppTheme.textMuted)
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

    var mediaSection: some View {
        ZStack {
            if APIConfig.screenshotMode {
                // Screenshot mode: gradient placeholder + play icon, no real art
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.posterGradient)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 56, weight: .regular))
                            .foregroundStyle(.white.opacity(0.9))
                    }
            } else if let path = movie.backdropPath, let url = URL(string: "https://image.tmdb.org/t/p/w780\(path)") {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .posterBlur()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.posterGradient)
                        .aspectRatio(16 / 9, contentMode: .fit)
                }
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.posterGradient)
                    .aspectRatio(16 / 9, contentMode: .fit)
            }

            if showTrailer, let videoId = trailerVideoId {
                ReelTrailerView(videoId: videoId)
                    .aspectRatio(
                        16 / 9, contentMode: .fit
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 14)
                    )
            }
        }
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
                    .foregroundStyle(AppTheme.textMuted)

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
        .foregroundStyle(AppTheme.textMuted)
        .padding(.vertical, 8)
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
