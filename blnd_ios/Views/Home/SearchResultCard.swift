import SwiftUI

/// Where a search poster goes. Movies open movie detail. TV opens TV detail.
enum SearchResultDestination: Equatable {
    case movie(tmdbId: Int)
    case tv(tmdbId: Int)

    /// Movie rows are buttons. TV rows use the same trait.
    static let rowTraits = AccessibilityTraits.isButton

    static func forMedia(_ mediaType: MediaType?, tmdbId: Int) -> SearchResultDestination {
        mediaType == .tv ? .tv(tmdbId: tmdbId) : .movie(tmdbId: tmdbId)
    }
}

/// Search poster. Movie and TV rows are both plain buttons with `rowTraits`.
struct SearchResultCard: View {
    let tmdbId: Int
    let title: String
    var year: String = ""
    var posterPath: String?
    var overview: String?
    var mediaType: MediaType?
    let cardWidth: CGFloat

    private var destination: SearchResultDestination {
        SearchResultDestination.forMedia(mediaType, tmdbId: tmdbId)
    }

    var body: some View {
        NavigationLink {
            switch destination {
            case .movie:
                MovieDetailView(tmdbId: tmdbId, title: title, source: .search)
            case .tv:
                TVDetailView(
                    tmdbId: tmdbId,
                    title: title,
                    year: year,
                    overview: overview
                )
            }
        } label: {
            MovieCard(
                tmdbId: tmdbId,
                title: title,
                year: year,
                posterPath: posterPath,
                width: cardWidth,
                height: cardWidth * 1.5,
                mediaType: mediaType
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(SearchResultDestination.rowTraits)
    }
}

/// Title and overview for a series. Search has no separate TV payload.
struct TVDetailView: View {
    let tmdbId: Int
    let title: String
    var year: String = ""
    var overview: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text(year.isEmpty ? "TV series" : "TV series · \(year)")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                if let overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .accessibilityIdentifier("tv-detail-\(tmdbId)")
    }
}
