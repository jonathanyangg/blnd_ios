import SwiftUI

private enum DragAxis {
    case undecided
    case horizontal
    case vertical
}

struct ReelCardView: View {
    let movie: ReelMovie
    let isActive: Bool
    var fullDetail: MovieResponse?
    var groupContext: GroupContext?
    var onWatchlistAdded: ((String) -> Void)?
    var onRated: ((Double) -> Void)?

    struct GroupContext {
        let groupId: Int
        let groupName: String
    }

    @State private var showActions = false
    @State private var horizontalOffset: CGFloat = 0
    @State private var dragAxis: DragAxis = .undecided
    @State private var showRating = false
    @State private var hideActionsTask: Task<Void, Never>?
    @State private var showDetail = false

    private let swipeThreshold: CGFloat = 120

    private var trailerVideoId: String? {
        let url = fullDetail?.trailerUrl ?? movie.trailerUrl
        return url.flatMap { YouTubePlayerView.extractVideoId(from: $0) }
    }

    var body: some View {
        ZStack {
            posterLayer
            trailerLayer
            scrimGradient
            infoOverlay
            actionButtonsOverlay
            swipeIndicators

            if showRating {
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
        .offset(x: horizontalOffset)
        .rotationEffect(.degrees(Double(horizontalOffset) * 0.02))
        .simultaneousGesture(horizontalDrag)
        .onTapGesture { toggleActions() }
        .containerRelativeFrame(.vertical)
        .clipped()
        .background(
            NavigationLink(
                destination: MovieDetailView(
                    tmdbId: movie.tmdbId,
                    title: movie.title
                ),
                isActive: $showDetail
            ) { EmptyView() }
                .hidden()
        )
    }

    // MARK: - Poster

    private var posterLayer: some View {
        Group {
            let path = fullDetail?.backdropPath
                ?? movie.backdropPath ?? movie.posterPath
            if let path, let url = posterURL(path) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .containerRelativeFrame(
                                [.horizontal, .vertical]
                            )
                            .clipped()
                    default:
                        posterPlaceholder
                    }
                }
            } else {
                posterPlaceholder
            }
        }
    }

    private var posterPlaceholder: some View {
        AppTheme.posterGradient
            .containerRelativeFrame([.horizontal, .vertical])
    }

    // MARK: - Trailer

    @ViewBuilder
    private var trailerLayer: some View {
        if isActive, !showRating, let videoId = trailerVideoId {
            ReelTrailerView(videoId: videoId)
                .containerRelativeFrame([.horizontal, .vertical])
                .clipped()
                .allowsHitTesting(false)
        }
    }

    // MARK: - Scrim

    private var scrimGradient: some View {
        VStack(spacing: 0) {
            // Top fade for status bar
            LinearGradient(
                colors: [.black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)

            Spacer()

            // Bottom fade for info overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 240)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Info Overlay

    private var infoOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(radius: 4)

                HStack(spacing: 8) {
                    if !movie.yearString.isEmpty {
                        Text(movie.yearString)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    if let pct = movie.scorePercent {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                            Text("\(pct)%")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                    }
                }

                if let overview = fullDetail?.overview ?? movie.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtonsOverlay: some View {
        if showActions, !showRating {
            VStack(alignment: .trailing, spacing: 0) {
                Spacer()
                VStack(spacing: 16) {
                    actionButton(
                        icon: "bookmark",
                        label: "Save"
                    ) {
                        addToWatchlist()
                    }
                    actionButton(
                        icon: "star",
                        label: "Rate"
                    ) {
                        showRating = true
                        showActions = false
                    }
                    actionButton(
                        icon: "info.circle",
                        label: "Info"
                    ) {
                        showDetail = true
                    }
                }
                .padding(.bottom, 100)
                .padding(.trailing, 16)
            }
            .transition(.opacity)
        }
    }

    private func actionButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Swipe Indicators

    @ViewBuilder
    private var swipeIndicators: some View {
        if horizontalOffset < -15 {
            HStack {
                Spacer()
                ReelSwipeIndicator(
                    offset: horizontalOffset,
                    threshold: swipeThreshold,
                    isLeft: true
                )
                .padding(.trailing, 40)
            }
        }
        if horizontalOffset > 15 {
            HStack {
                ReelSwipeIndicator(
                    offset: horizontalOffset,
                    threshold: swipeThreshold,
                    isLeft: false
                )
                .padding(.leading, 40)
                Spacer()
            }
        }
    }

    // MARK: - Gestures

    private var horizontalDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let dxx = abs(value.translation.width)
                let dyy = abs(value.translation.height)
                if dragAxis == .undecided, dxx > 15 || dyy > 15 {
                    dragAxis = dxx > dyy ? .horizontal : .vertical
                }
                if dragAxis == .horizontal {
                    horizontalOffset = value.translation.width
                }
            }
            .onEnded { _ in
                if dragAxis == .horizontal {
                    if horizontalOffset < -swipeThreshold {
                        addToWatchlist()
                    } else if horizontalOffset > swipeThreshold {
                        showRating = true
                    }
                }
                withAnimation(.easeOut(duration: 0.25)) {
                    horizontalOffset = 0
                }
                dragAxis = .undecided
            }
    }

    // MARK: - Actions

    private func toggleActions() {
        hideActionsTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showActions.toggle()
        }
        if showActions {
            hideActionsTask = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showActions = false
                }
            }
        }
    }

    private func addToWatchlist() {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()

        Task {
            do {
                if let ctx = groupContext {
                    _ = try await GroupsAPI.addToWatchlist(
                        groupId: ctx.groupId,
                        tmdbId: movie.tmdbId
                    )
                    onWatchlistAdded?(
                        "Added to \(ctx.groupName) Watchlist"
                    )
                } else {
                    _ = try await TrackingAPI.addToWatchlist(
                        tmdbId: movie.tmdbId
                    )
                    onWatchlistAdded?("Added to My Watchlist")
                }
            } catch {
                print("[ReelCardView] watchlist error: \(error)")
            }
        }
    }

    private func posterURL(_ path: String) -> URL? {
        URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }
}
