import SwiftUI

struct ReelCardView: View {
    let movie: ReelMovie
    let isActive: Bool
    /// False while scrolling, behind the detail sheet, or in the background. Stops the trailer.
    var canPlay = true
    /// Clears the floating tab bar the card now extends behind.
    var bottomInset: CGFloat = 0
    var position: Int = 0
    var feed: Analytics.FeedSource = .fyp
    var onSwipeResult: ((ReelSwipeResult) -> Void)?
    var onRequestWatchlist: (() -> Void)?
    var onRated: ((Double) -> Void)?
    var onMutationFailed: ((UserFacingError, @escaping () -> Void) -> Void)?
    var onShowDetail: (() -> Void)?
    var onShowFriend: ((FriendResponse) -> Void)?
    var tutorialNudge: ReelTutorialNudge = .rest
    var showsTutorial = false

    @State var swipeOffset: CGFloat = 0
    @State var swipeTriggeredHaptic = false
    @State var isDragging = false
    @State var hold = TrailerPlaybackState()
    @State var trailerKind: TrailerSourceKind?
    @State var trailerTask: Task<Void, Never>?
    @State var showTrailerUnavailable = false
    @State var providers: [WatchOffer] = []
    @State var friendsWhoWatched: [FriendWatchedResponse] = []
    @State var showStreamingSheet = false
    @State var showCommentsSheet = false
    @State var showWatchedBySheet = false
    @State var showLogSheet = false
    @State var friendsLoadTask: Task<Void, Never>?
    @State var selectedCastMember: CastMember?
    @State private var activeStartTime: Date?
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let swipeThreshold: CGFloat = 120

    var genres: [Genre] {
        movie.genres.filter { $0.name != nil }
    }

    var body: some View {
        ZStack {
            posterBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            trailerLayer
            if hold.showsOverlay {
                scrim
                    .transition(.opacity)
                infoOverlay
                    .transition(.opacity)
            }
            trailerHUD
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: posterTapped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.black)
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: hold)
        .coordinateSpace(name: "reelCard")
        .offset(x: swipeOffset + tutorialNudge.x, y: tutorialNudge.y)
        .rotationEffect(
            .degrees(Double(swipeOffset) * 0.02 + tutorialNudge.degrees)
        )
        .reelTutorialFrame(.card, active: isActive)
        .simultaneousGesture(horizontalSwipe)
        .overlay { swipeIndicators }
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
                activeStartTime = Date()
            }
        }
        .task(id: isActive) {
            if isActive { await loadProviders() }
        }
        .onChange(of: canPlay && isActive && !showsTutorial) { _, playable in
            if !playable { apply(hold.send(.stopped)) }
        }
        .onChange(of: TrailerPlayer.shared.endedCount) { _, _ in
            if hold.isPlaying { apply(hold.send(.ended)) }
        }
        .onChange(of: isActive) { _, active in
            if active {
                activeStartTime = Date()
                loadFriends()
            } else {
                if let start = activeStartTime {
                    Analytics.reelViewed(
                        tmdbId: movie.tmdbId,
                        position: position,
                        feed: feed,
                        timeOnCardMs: Int(Date().timeIntervalSince(start) * 1000)
                    )
                    activeStartTime = nil
                }
            }
        }
    }
}
