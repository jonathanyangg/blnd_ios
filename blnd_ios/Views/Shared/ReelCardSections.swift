import SwiftUI

// MARK: - View Sections

extension ReelCardView {
    // MARK: - Title

    var titleRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                Text(movie.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let pct = movie.scorePercent {
                    matchBadge(pct)
                }
            }

            if hasDetail {
                metaLine
            } else {
                HStack(spacing: 8) {
                    if !movie.yearString.isEmpty {
                        Text(movie.yearString)
                            .font(.system(size: 14))
                            .foregroundStyle(
                                AppTheme.textMuted
                            )
                    }
                    SkeletonRect(width: 80, height: 12)
                }
            }
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
        var parts: [String] = []
        if !movie.yearString.isEmpty {
            parts.append(movie.yearString)
        }
        if let runtime = fullDetail?.runtimeFormatted {
            parts.append(runtime)
        }
        if let vote = fullDetail?.voteAverage, vote > 0 {
            parts.append(
                "★ \(String(format: "%.1f", vote))"
            )
        }
        if let director = fullDetail?.director {
            parts.append(director)
        }
        return parts
    }

    // MARK: - Media

    var mediaSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.card)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if !showTrailer {
                        Image(systemName: "play.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                AppTheme.textDim
                            )
                    }
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
            if hasDetail {
                if !genres.isEmpty {
                    genrePills
                }

                cardTagline

                cardOverview

                compactCastSection

                compactFriendsSection
            } else {
                skeletonDetails
            }
        }
    }

    // MARK: - Friends Who Watched (Compact)

    @ViewBuilder
    var compactFriendsSection: some View {
        if !friendsWhoWatched.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Watched by")
                    .font(.system(
                        size: 13, weight: .semibold
                    ))
                    .foregroundStyle(
                        AppTheme.textMuted
                    )

                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(spacing: 10) {
                        ForEach(
                            friendsWhoWatched
                        ) { friend in
                            friendTile(friend)
                        }
                    }
                }
            }
        }
    }

    func friendTile(_ friend: FriendWatchedResponse) -> some View {
        VStack(spacing: 3) {
            AvatarView(url: friend.avatarUrl, size: 36)
            Text(friend.displayName ?? friend.username)
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
        if let tagline = fullDetail?.tagline, !tagline.isEmpty {
            Text(tagline)
                .font(.system(
                    size: 13, weight: .medium
                ))
                .foregroundStyle(.white.opacity(0.7))
                .italic()
                .lineLimit(2)
        }
    }

    // MARK: - Overview (Expandable)

    @ViewBuilder
    var cardOverview: some View {
        let text = fullDetail?.overview
            ?? movie.overview
        if let text, !text.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineSpacing(3)
                    .lineLimit(
                        overviewExpanded ? nil : 3
                    )

                if !overviewExpanded {
                    Button {
                        withAnimation(
                            .easeInOut(duration: 0.2)
                        ) {
                            overviewExpanded = true
                        }
                    } label: {
                        Text("more")
                            .font(.system(
                                size: 13,
                                weight: .medium
                            ))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    // MARK: - Compact Cast

    @ViewBuilder
    var compactCastSection: some View {
        if let cast = fullDetail?.cast, !cast.isEmpty {
            ScrollView(
                .horizontal, showsIndicators: false
            ) {
                HStack(spacing: 10) {
                    ForEach(
                        Array(
                            cast.prefix(8)
                                .enumerated()
                        ),
                        id: \.offset
                    ) { _, member in
                        VStack(spacing: 3) {
                            castAvatar(member)
                            Text(member.name)
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
        ScrollView(.horizontal, showsIndicators: false) {
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
            }
        }
    }

    // MARK: - Skeleton

    var skeletonDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SkeletonRect(width: 60, height: 24)
                SkeletonRect(width: 80, height: 24)
                SkeletonRect(width: 55, height: 24)
            }

            VStack(alignment: .leading, spacing: 6) {
                SkeletonRect(height: 12)
                SkeletonRect(height: 12)
                SkeletonRect(width: 200, height: 12)
            }
        }
    }

    // MARK: - Swipe Indicators

    @ViewBuilder
    var swipeIndicators: some View {
        if swipeOffset < -15 {
            HStack {
                Spacer()
                ReelSwipeIndicator(
                    offset: swipeOffset,
                    threshold: swipeThreshold,
                    isLeft: true
                )
                .padding(.trailing, 40)
            }
        }
        if swipeOffset > 15 {
            HStack {
                ReelSwipeIndicator(
                    offset: swipeOffset,
                    threshold: swipeThreshold,
                    isLeft: false
                )
                .padding(.leading, 40)
                Spacer()
            }
        }
    }

    // MARK: - Rating Overlay

    var ratingOverlay: some View {
        ReelRatingOverlay(
            title: movie.title,
            tmdbId: movie.tmdbId,
            onDismiss: { showRating = false },
            onSaved: { rating in
                showRating = false
                onRated?(rating)
            }
        )
    }
}
