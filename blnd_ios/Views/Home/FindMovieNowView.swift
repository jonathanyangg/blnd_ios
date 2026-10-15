import SwiftUI

/// One pick from `GET /recommendations/now`. A 404 is an empty filter, not a failure.
struct FindMovieNowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = CatalogFilterStore.shared
    @State private var pick: NowPickResponse?
    @State private var noMatch = false
    @State private var failure: String?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.white)
            } else if noMatch {
                CatalogFilterNotice(
                    title: "Nothing matches those filters",
                    button: "Loosen filters"
                ) {
                    store.update(CatalogFilter())
                }
            } else if let failure {
                CatalogFilterNotice(title: failure)
            } else if let pick {
                VStack(spacing: 12) {
                    Text(pick.reason)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    MovieCard(
                        tmdbId: pick.movie.tmdbId,
                        title: pick.movie.title,
                        year: pick.movie.yearString,
                        posterPath: pick.movie.posterPath,
                        width: 180,
                        height: 270,
                        mediaType: pick.movie.mediaType
                    )
                }
            }
        }
        .accessibilityIdentifier("find-movie-now")
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.card)
                    .clipShape(Circle())
            }
            .padding(20)
            .accessibilityIdentifier("find-movie-now.close")
        }
        .task(id: store.filter) { await load() }
    }

    private func load() async {
        isLoading = true
        failure = nil
        noMatch = false
        do {
            pick = try await RecommendationsAPI.findNow(filter: store.current())
        } catch APIError.notFound {
            pick = nil
            noMatch = true
        } catch {
            pick = nil
            failure = error.localizedDescription
        }
        isLoading = false
    }
}
