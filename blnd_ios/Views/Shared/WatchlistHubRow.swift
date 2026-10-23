import SwiftUI

/// Under a watchlist poster: top provider logos and Watch now. Loads lazily
/// per visible tile through `WatchProviderCache`.
struct WatchlistHubRow: View {
    let movie: WatchlistMovieResponse
    let index: Int

    @State private var payload: WhereToWatch?
    @State private var loaded = false

    var body: some View {
        HStack(spacing: 4) {
            if !loaded {
                ProgressView()
                    .controlSize(.mini)
                    .tint(AppTheme.textDim)
            } else if let payload, let best = payload.hubOffers.first {
                HStack(spacing: -4) {
                    ForEach(payload.topProviders(limit: 2)) { offer in
                        logo(offer)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if movie.mediaType != .tv {
                        PendingWatchStore().opened(tmdbId: movie.tmdbId, title: movie.title, posterPath: movie.posterPath)
                    }
                    Task { await WatchLinkOpener.open(best.offer, kind: best.kind) }
                } label: {
                    Text("Watch now")
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Watch \(movie.title) on \(best.offer.providerName)")
                .accessibilityIdentifier("watchlist.watchNow.\(index)")
            } else {
                Text("Not streaming right now")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        .task(id: movie.tmdbId) {
            payload = await WatchProviderCache.shared.whereToWatch(
                tmdbId: movie.tmdbId,
                mediaType: movie.mediaType ?? .movie
            )
            loaded = true
        }
    }

    @ViewBuilder
    private func logo(_ offer: WatchOffer) -> some View {
        let fallback = Text(String(offer.providerName.prefix(1)))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(AppTheme.cardSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        Group {
            if let url = offer.logoURL {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppTheme.background, lineWidth: 1))
        .accessibilityLabel(offer.providerName)
    }
}
