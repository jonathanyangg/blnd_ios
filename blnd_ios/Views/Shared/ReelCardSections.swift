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

                Spacer()

                hideButton
            }

            metaLine
        }
    }

    var hideButton: some View {
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
                isHidden ? .red : AppTheme.textDim
            )
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
            Text(
                "This movie won't show in your "
                    + "recommendations."
            )
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
            if !genres.isEmpty {
                genrePills
            }

            cardTagline

            cardOverview

            if !overviewExpanded {
                compactCastSection
                compactFriendsSection
            }
        }
    }

    // MARK: - Friends Who Watched (Compact, always visible)

    var compactFriendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Watched by")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)

            if friendsWhoWatched.isEmpty {
                Text("No friends have seen this movie")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textDim)
            } else {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(spacing: 10) {
                        ForEach(
                            friendsWhoWatched
                        ) { friend in
                            NavigationLink {
                                FriendProfileView(
                                    friend: friend
                                        .asFriendResponse
                                )
                            } label: {
                                friendTile(friend)
                            }
                            .buttonStyle(.plain)
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
        if let tagline = movie.tagline, !tagline.isEmpty {
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

    private var overviewMaxHeight: CGFloat {
        80 // ~5 lines at 13pt font + 3pt lineSpacing
    }

    @ViewBuilder
    var cardOverview: some View {
        if let text = movie.overview, !text.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineSpacing(3)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: overviewExpanded
                            ? .infinity : overviewMaxHeight,
                        alignment: .topLeading
                    )
                    .clipped()
                    .overlay {
                        Text(text)
                            .font(.system(size: 13))
                            .lineSpacing(3)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                            .hidden()
                            .background(GeometryReader { geo in
                                Color.clear.preference(
                                    key: OverviewFullH.self,
                                    value: geo.size.height
                                )
                            })
                    }
                    .onPreferenceChange(OverviewFullH.self) {
                        overviewFullHeight = $0
                    }

                if overviewExpanded || overviewFullHeight > overviewMaxHeight + 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            overviewExpanded.toggle()
                        }
                    } label: {
                        Text(overviewExpanded ? "less" : "more")
                            .font(.system(
                                size: 13, weight: .medium
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

    // MARK: - Rating Overlay

    var ratingOverlay: some View {
        ReelRatingOverlay(title: movie.title, tmdbId: movie.tmdbId, onDismiss: { showRating = false }, onSaved: {
            showRating = false
            onRated?($0)
        })
    }
}
