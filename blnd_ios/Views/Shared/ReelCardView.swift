import SwiftUI

struct ReelCardView: View {
    let movie: ReelMovie
    let isActive: Bool
    var groupContext: GroupContext?
    var position: Int = 0
    var feed: Analytics.FeedSource = .fyp
    var onWatchlistAdded: ((String) -> Void)?
    var onRated: ((Double) -> Void)?
    var onShowDetail: (() -> Void)?
    var onShowFriend: ((FriendResponse) -> Void)?

    struct GroupContext {
        let groupId: Int
        let groupName: String
    }

    @State var swipeOffset: CGFloat = 0
    @State var swipeTriggeredHaptic = false
    @State var isDragging = false
    @State var trailerReady = false
    @State var friendsWhoWatched: [FriendWatchedResponse] = []
    @State var showStreamingSheet = false
    @State var showCommentsSheet = false
    @State var showWatchedBySheet = false
    @State var showLogSheet = false
    @State var friendsLoadTask: Task<Void, Never>?
    @State var mediaBottomY: CGFloat = 0
    @State var selectedCastMember: CastMember?
    @State private var activeStartTime: Date?

    let swipeThreshold: CGFloat = 120

    var trailerVideoId: String? {
        movie.trailerUrl.flatMap {
            YouTubePlayerView.extractVideoId(from: $0)
        }
    }

    var genres: [Genre] {
        movie.genres.filter { $0.name != nil }
    }

    var showTrailer: Bool {
        !APIConfig.screenshotMode
            && isActive && trailerReady && trailerVideoId != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleLine
                .padding(.top, 22)
                .padding(.horizontal, 20)
                .layoutPriority(10)

            // Title ↔ meta: small flexible gap (8–10pt).
            Spacer(minLength: 8)
                .frame(maxHeight: 10)

            metaLine
                .padding(.horizontal, 20)
                .layoutPriority(10)

            if !genres.isEmpty {
                genrePills
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .layoutPriority(5)
            }

            mediaSection
                .padding(.top, 12)
                .padding(.horizontal, 4)
                .background(GeometryReader { geo in
                    Color.clear.preference(
                        key: MediaBottomYKey.self,
                        value: geo.frame(in: .named("reelCard")).maxY
                    )
                })
                .layoutPriority(10)

            // Video ↔ actions: the main flexible gap that fills remaining height.
            Spacer(minLength: 10)

            // Action block: Comments → Watched by → Rating.
            VStack(spacing: 12) {
                commentsButton
                watchedByRow
                inlineRatingBar
                watchedWithButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .layoutPriority(10)

            Divider()
                .overlay(AppTheme.border)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .layoutPriority(10)

            // Watch Now is the bottom-anchored primary CTA.
            watchNowButton
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
                .layoutPriority(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .coordinateSpace(name: "reelCard")
        .onPreferenceChange(MediaBottomYKey.self) { mediaBottomY = $0 }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .offset(x: swipeOffset)
        .rotationEffect(
            .degrees(Double(swipeOffset) * 0.02)
        )
        .simultaneousGesture(horizontalSwipe)
        .overlay { swipeIndicators }
        .onTapGesture {
            guard !isDragging else { return }
            onShowDetail?()
        }
        .sheet(item: $selectedCastMember) { member in
            NavigationStack {
                ActorProfileView(
                    personId: member.id,
                    name: member.name,
                    profilePath: member.profilePath
                )
            }
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.background)
        }
        .sheet(isPresented: $showStreamingSheet) {
            StreamingSheet(tmdbId: movie.tmdbId, title: movie.title)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.card)
        }
        .sheet(isPresented: $showCommentsSheet) {
            MovieCommentsView(
                tmdbId: movie.tmdbId,
                movieTitle: movie.title
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
        .sheet(isPresented: $showLogSheet) {
            RateMovieSheet(
                title: movie.title,
                year: movie.yearString,
                tmdbId: movie.tmdbId,
                posterPath: movie.posterPath,
                existingRating: UserActionCache.shared.rating(for: movie.tmdbId)
            ) { newRating in
                onRated?(newRating)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
        .sheet(isPresented: $showWatchedBySheet) {
            WatchedBySheet(friends: friendsWhoWatched) { friend in
                showWatchedBySheet = false
                // Let the sheet dismiss, then push the profile as a full page.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onShowFriend?(friend)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
        .onAppear {
            if isActive {
                trailerReady = true
                activeStartTime = Date()
                if let vid = trailerVideoId {
                    TrailerPlayer.shared.play(videoId: vid)
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                trailerReady = true
                activeStartTime = Date()
                loadFriends()
                if let vid = trailerVideoId {
                    TrailerPlayer.shared.play(videoId: vid)
                }
            } else {
                trailerReady = false
                if let start = activeStartTime {
                    Analytics.reelViewed(
                        tmdbId: movie.tmdbId,
                        position: position,
                        feed: feed,
                        timeOnCardMs: Int(Date().timeIntervalSince(start) * 1000)
                    )
                    activeStartTime = nil
                }
                // Don't call stop() here — loadVideo() on the next card
                // implicitly replaces the current video. An explicit stop()
                // races with the next card's play() and kills it.
            }
        }
    }
}
