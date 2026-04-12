import SwiftUI

struct ReelCardView: View {
    let movie: ReelMovie
    let isActive: Bool
    var groupContext: GroupContext?
    var onWatchlistAdded: ((String) -> Void)?
    var onRated: ((Double) -> Void)?

    struct GroupContext {
        let groupId: Int
        let groupName: String
    }

    @State var swipeOffset: CGFloat = 0
    @State var swipeTriggeredHaptic = false
    @State var showRating = false
    @State var isDragging = false
    @State var trailerReady = false
    @State var overviewExpanded = false
    @State var overviewFullHeight: CGFloat = 0
    @State var overviewTruncatedHeight: CGFloat = 0
    @State var friendsWhoWatched: [FriendWatchedResponse] = []
    @State var cardSize: CGSize = .zero
    @State var showStreamingSheet = false
    @State var friendsLoadTask: Task<Void, Never>?
    @State var overviewMaxHeightValue: CGFloat = 80

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
            titleRow
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            mediaSection
                .padding(.horizontal, 16)

            detailsSection
                .padding(.top, 14)
                .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .background(GeometryReader { geo in
            Color.clear.onAppear {
                cardSize = geo.size
            }
        })
        .offset(x: swipeOffset)
        .rotationEffect(
            .degrees(Double(swipeOffset) * 0.02)
        )
        .simultaneousGesture(horizontalSwipe)
        .overlay { swipeIndicators }
        .overlay {
            if showRating {
                ratingOverlay
            }
        }
        .sheet(isPresented: $showStreamingSheet) {
            StreamingSheet(tmdbId: movie.tmdbId, title: movie.title)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.card)
        }
        .onAppear {
            if isActive {
                trailerReady = true
                if let vid = trailerVideoId {
                    TrailerPlayer.shared.play(videoId: vid)
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                trailerReady = true
                loadFriends()
                if let vid = trailerVideoId {
                    TrailerPlayer.shared.play(videoId: vid)
                }
            } else {
                trailerReady = false
                overviewExpanded = false
                // Don't call stop() here — loadVideo() on the next card
                // implicitly replaces the current video. An explicit stop()
                // races with the next card's play() and kills it.
            }
        }
        .onChange(of: cardSize) { _, size in
            overviewMaxHeightValue = computeOverviewMaxHeight(size)
        }
        .onChange(of: showRating) { _, rating in
            guard isActive else { return }
            if rating {
                TrailerPlayer.shared.pause()
            } else {
                TrailerPlayer.shared.resume()
            }
        }
    }
}
