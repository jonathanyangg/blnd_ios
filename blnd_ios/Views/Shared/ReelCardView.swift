import SwiftUI

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

    @State var swipeOffset: CGFloat = 0
    @State var swipeTriggeredHaptic = false
    @State var showRating = false
    @State var isDragging = false
    @State var trailerReady = false
    @State var overviewExpanded = false

    let swipeThreshold: CGFloat = 120

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
                overviewExpanded = false
            }
        }
    }

    func scheduleTrailer() {
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.1
        ) {
            trailerReady = true
        }
    }
}

// MARK: - Skeleton Rect

struct SkeletonRect: View {
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
