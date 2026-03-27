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

    let swipeThreshold: CGFloat = 120

    @State var fullDetail: MovieResponse?

    var trailerVideoId: String? {
        let url = fullDetail?.trailerUrl ?? movie.trailerUrl
        return url.flatMap {
            YouTubePlayerView.extractVideoId(from: $0)
        }
    }

    var genres: [Genre] {
        let list = fullDetail?.genres ?? movie.genres
        return list.filter { $0.name != nil }
    }

    var showTrailer: Bool {
        isActive && trailerReady && !showRating
            && trailerVideoId != nil
    }

    var hasDetail: Bool {
        fullDetail != nil
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
        .task {
            if let cached = UserActionCache.shared.movieDetails[movie.tmdbId] {
                fullDetail = cached
            } else {
                do {
                    let detail = try await MoviesAPI.getMovie(tmdbId: movie.tmdbId)
                    UserActionCache.shared.cacheMovieDetail(detail)
                    fullDetail = detail
                } catch {}
            }
        }
        .onAppear {
            if isActive {
                trailerReady = true
                loadFriends()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                trailerReady = true
                loadFriends()
            } else {
                trailerReady = false
                overviewExpanded = false
            }
        }
    }
}

// MARK: - Skeleton Rect

struct SkeletonRect: View {
    var width: CGFloat?
    var height: CGFloat = 14

    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(AppTheme.card)
            .frame(
                maxWidth: width ?? .infinity,
                minHeight: height,
                maxHeight: height
            )
            .opacity(shimmer ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: shimmer
            )
            .onAppear { shimmer = true }
    }
}
