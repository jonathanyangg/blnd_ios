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
    @State var isDragging = false
    @State var trailerReady = false
    @State var overviewExpanded = false
    @State var overviewFullHeight: CGFloat = 0
    @State var overviewCappedHeight: CGFloat = 0
    @State var friendsWhoWatched: [FriendWatchedResponse] = []
    @State var showStreamingSheet = false
    @State var friendsLoadTask: Task<Void, Never>?
    @State var mediaBottomY: CGFloat = 0

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
                .layoutPriority(10)

            mediaSection
                .padding(.horizontal, 4)
                .background(GeometryReader { geo in
                    Color.clear.preference(
                        key: MediaBottomYKey.self,
                        value: geo.frame(in: .named("reelCard")).maxY
                    )
                })
                .layoutPriority(10)

            detailsSection
                .padding(.top, 14)
                .padding(.horizontal, 20)
                .layoutPriority(5)

            Spacer(minLength: 8)

            if !overviewExpanded {
                Divider()
                    .overlay(AppTheme.border)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .layoutPriority(10)

                inlineRatingBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 26)
                    .layoutPriority(10)
            }
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
    }
}
