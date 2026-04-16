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

    var titleRow: some View {
        VStack(alignment: .leading, spacing: 5) {
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

                streamingButton
            }

            metaLine
        }
    }

    var streamingButton: some View {
        Button { showStreamingSheet = true } label: {
            Image(systemName: "tv")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textDim)
        }
    }

    func matchBadge(_ pct: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.aiPurple)
            Text("\(pct)%")
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

            overviewGroup
                .layoutPriority(1)

            if overviewExpanded {
                compactCastSection
                    .layoutPriority(4)
            } else {
                compactFriendsSection
                    .layoutPriority(5)
            }
        }
    }

    /// Overview + its toggle button. In collapsed state, `ViewThatFits`
    /// picks the first variant that fits — so the overview grows up to
    /// 5 lines when there's room, shrinks down to 1 line when tight,
    /// and disappears entirely when there isn't even room for one line
    /// (tagline wins, since it has higher layoutPriority).
    @ViewBuilder
    var overviewGroup: some View {
        if overviewExpanded {
            VStack(alignment: .leading, spacing: 3) {
                cardOverview
                lessButton
            }
        } else if !overviewText.isEmpty {
            ViewThatFits(in: .vertical) {
                collapsedOverviewBlock(lines: 5)
                collapsedOverviewBlock(lines: 4)
                collapsedOverviewBlock(lines: 3)
                collapsedOverviewBlock(lines: 2)
                collapsedOverviewBlock(lines: 1)
                EmptyView()
            }
        }
    }

    /// One collapsed-state variant: overview capped at `lines` plus the
    /// "more" button. Button shows if either the overview is truncated at
    /// this cap OR there's a cast to reveal in the expanded state.
    func collapsedOverviewBlock(lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            overviewTextView(lineCap: lines)
            if isOverviewTruncated || !movie.cast.isEmpty {
                moreButton
            }
        }
    }

    var moreButton: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    overviewExpanded = true
                }
            } label: {
                Text("more")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    var lessButton: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    overviewExpanded = false
                }
            } label: {
                Text("less")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Friends Who Watched (Compact, only when at least one friend watched)

    @ViewBuilder
    var compactFriendsSection: some View {
        if !friendsWhoWatched.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Watched by")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(
                            Array(friendsWhoWatched.enumerated()),
                            id: \.element.id
                        ) { idx, friend in
                            NavigationLink {
                                FriendProfileView(
                                    friend: friend
                                        .asFriendResponse
                                )
                            } label: {
                                friendTile(friend, index: idx)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    func friendTile(_ friend: FriendWatchedResponse, index: Int) -> some View {
        VStack(spacing: 3) {
            AvatarView(url: friend.avatarUrl, size: 36)
            Text(
                APIConfig.screenshotMode
                    ? ScreenshotDummy.friendDisplayName(at: index)
                    : (friend.displayName ?? friend.username)
            )
            .font(.system(size: 9))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(width: 36)
            if let rating = friend.rating {
                let text = rating.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", rating)
                    : String(format: "%.1f", rating)
                HStack(spacing: 2) {
                    Image(systemName: "star.fill").font(.system(size: 7))
                    Text(text).font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.black.opacity(0.7))
                .clipShape(Capsule())
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
                        id: \.offset
                    ) { idx, member in
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
                }
            }
        }
    }

    @ViewBuilder
    func castAvatar(
        _ member: CastMember
    ) -> some View {
        let base = "https://image.tmdb.org/t/p/w185"
        if let path = member.profilePath, let url = URL(string: "\(base)\(path)") {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .posterBlur()
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(AppTheme.card)
                    .frame(width: 36, height: 36)
            }
        } else {
            Circle()
                .fill(AppTheme.card)
                .frame(width: 36, height: 36)
        }
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
