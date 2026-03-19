import SwiftUI

struct ReelCardView: View {
    let movie: ReelMovie
    let isActive: Bool
    var fullDetail: MovieResponse?
    var groupContext: GroupContext?
    var onWatchlistAdded: ((String) -> Void)?
    var onRated: ((Double) -> Void)?
    var onNavigateToDetail: ((Int, String) -> Void)?

    struct GroupContext {
        let groupId: Int
        let groupName: String
    }

    @GestureState var dragOffset: CGFloat = 0
    @State var showRating = false
    @State var isDragging = false
    @State var trailerReady = false

    let swipeThreshold: CGFloat = 120

    private var trailerVideoId: String? {
        let url = fullDetail?.trailerUrl ?? movie.trailerUrl
        return url.flatMap {
            YouTubePlayerView.extractVideoId(from: $0)
        }
    }

    private var genres: [Genre] {
        let list = fullDetail?.genres ?? movie.genres
        return list.filter { $0.name != nil }
    }

    private var showTrailer: Bool {
        isActive && trailerReady && !showRating
            && trailerVideoId != nil
    }

    private var hasDetail: Bool {
        fullDetail != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
                .contentShape(Rectangle())
                .onTapGesture { navigateToDetail() }

            mediaSection
                .padding(.horizontal, 16)

            detailsSection
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
                .onTapGesture { navigateToDetail() }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .offset(x: dragOffset)
        .rotationEffect(
            .degrees(Double(dragOffset) * 0.02)
        )
        .gesture(horizontalSwipe)
        .overlay { swipeIndicators }
        .overlay {
            if showRating {
                ratingOverlay
            }
        }
        .onAppear {
            if isActive, !trailerReady {
                scheduleTrailer()
            }
        }
        .onChange(of: isActive) { _, active in
            if active, !trailerReady {
                scheduleTrailer()
            }
            if !active {
                trailerReady = false
            }
        }
    }

    private func scheduleTrailer() {
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.5
        ) {
            trailerReady = true
        }
    }

    private func navigateToDetail() {
        guard !isDragging else { return }
        onNavigateToDetail?(movie.tmdbId, movie.title)
    }

    // MARK: - Title

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(movie.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            if hasDetail {
                metaLine
            } else {
                // Skeleton meta line
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

    private var metaLine: some View {
        HStack(spacing: 0) {
            let parts = metaParts
            ForEach(
                Array(parts.enumerated()),
                id: \.offset
            ) { index, part in
                if index > 0 {
                    Text(" · ")
                        .foregroundStyle(AppTheme.textDim)
                }
                Text(part)
            }

            if let pct = movie.scorePercent {
                if !metaParts.isEmpty {
                    Text("  ")
                }
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text("\(pct)%")
                        .font(.system(
                            size: 14,
                            weight: .bold
                        ))
                }
                .foregroundStyle(.white)
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(AppTheme.textMuted)
    }

    private var metaParts: [String] {
        var parts: [String] = []
        if !movie.yearString.isEmpty {
            parts.append(movie.yearString)
        }
        if let runtime = fullDetail?.runtimeFormatted {
            parts.append(runtime)
        }
        if let director = fullDetail?.director {
            parts.append(director)
        }
        return parts
    }

    // MARK: - Media

    private var mediaSection: some View {
        ZStack {
            // Skeleton video area — always present
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

            // Trailer on top when ready
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

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if hasDetail {
                if !genres.isEmpty {
                    genrePills
                }

                let text = fullDetail?.overview
                    ?? movie.overview
                if let text, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(4)
                        .lineSpacing(4)
                }
            } else {
                // Skeleton details
                skeletonDetails
            }
        }
    }

    private var skeletonDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Skeleton genre pills
            HStack(spacing: 6) {
                SkeletonRect(width: 60, height: 24)
                SkeletonRect(width: 80, height: 24)
                SkeletonRect(width: 55, height: 24)
            }

            // Skeleton overview lines
            VStack(alignment: .leading, spacing: 6) {
                SkeletonRect(height: 12)
                SkeletonRect(height: 12)
                SkeletonRect(width: 200, height: 12)
            }
        }
    }

    private var genrePills: some View {
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
    private var swipeIndicators: some View {
        if dragOffset < -15 {
            HStack {
                Spacer()
                ReelSwipeIndicator(
                    offset: dragOffset,
                    threshold: swipeThreshold,
                    isLeft: true
                )
                .padding(.trailing, 40)
            }
        }
        if dragOffset > 15 {
            HStack {
                ReelSwipeIndicator(
                    offset: dragOffset,
                    threshold: swipeThreshold,
                    isLeft: false
                )
                .padding(.leading, 40)
                Spacer()
            }
        }
    }

    // MARK: - Rating Overlay

    private var ratingOverlay: some View {
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

// MARK: - Skeleton Rect

private struct SkeletonRect: View {
    var width: CGFloat?
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(AppTheme.card)
            .frame(
                maxWidth: width ?? .infinity,
                minHeight: height,
                maxHeight: height
            )
    }
}
