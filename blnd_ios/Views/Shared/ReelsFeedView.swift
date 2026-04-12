import SwiftUI

struct ReelsFeedView: View {
    let movies: [ReelMovie]
    var groupContext: ReelCardView.GroupContext?
    var isTabVisible: Bool = true
    var onLoadMore: (() async -> Void)?
    var onRefresh: (() async -> Void)?

    @State private var currentId: Int?
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var watchlistTmdbId: Int?
    @State private var addedToWatchlist: Set<Int> = []
    @State private var lastHiddenTmdbId: Int?

    var body: some View {
        GeometryReader { geo in
            let cardHeight = geo.size.height

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(
                        Array(movies.enumerated()),
                        id: \.element.id
                    ) { _, movie in
                        ReelCardView(
                            movie: movie,
                            isActive: movie.tmdbId == currentId
                                && isTabVisible,
                            groupContext: groupContext,
                            onWatchlistAdded: { msg in
                                if msg.contains("Won't show") {
                                    lastHiddenTmdbId = movie.tmdbId
                                } else {
                                    addedToWatchlist.insert(
                                        movie.tmdbId
                                    )
                                }
                                showToast(msg)
                            },
                            onRated: { rating in
                                let text = String(
                                    format: "%.1f",
                                    rating
                                )
                                showToast(
                                    "Rated \(text) stars"
                                )
                            }
                        )
                        .frame(height: cardHeight)
                        .id(movie.tmdbId)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(
                .viewAligned(limitBehavior: .alwaysByOne)
            )
            .scrollPosition(id: $currentId)
            .scrollIndicators(.hidden)
        }
        .onChange(of: currentId) { _, newId in
            guard let newId else { return }
            if let idx = movies.firstIndex(where: {
                $0.tmdbId == newId
            }), idx >= movies.count - 4 {
                Task { await onLoadMore?() }
            }
        }
        .onChange(of: movies) { _, newMovies in
            if currentId.flatMap({ cid in newMovies.contains { $0.tmdbId == cid } }) != true {
                currentId = newMovies.first?.tmdbId
            }
        }
        .onAppear {
            if currentId == nil, let first = movies.first {
                currentId = first.tmdbId
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = toastMessage {
                ReelToast(
                    message: toast,
                    actionLabel: toastActionLabel(toast),
                    onAction: { handleToastAction(toast) }
                )
                .padding(.bottom, 24)
                .transition(
                    .move(edge: .top)
                        .combined(with: .opacity)
                )
            }
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: toastMessage
        )
        .sheet(
            item: Binding(
                get: { watchlistTmdbId.map { WatchlistItem(tmdbId: $0) } },
                set: { watchlistTmdbId = $0?.tmdbId }
            )
        ) { item in
            WatchlistPickerSheet(
                tmdbId: item.tmdbId,
                isWatched: false,
                isInPersonalWatchlist: addedToWatchlist
                    .contains(item.tmdbId)
            ) { _ in }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.card)
        }
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled {
                toastMessage = nil
            }
        }
    }

    private func toastActionLabel(_ toast: String) -> String? {
        if toast.contains("Watchlist") { return "Change" }
        if toast.contains("Won't show") { return "Undo" }
        return nil
    }

    private func handleToastAction(_ toast: String) {
        toastMessage = nil
        if toast.contains("Watchlist") {
            if let curId = currentId {
                watchlistTmdbId = curId
            }
        } else if toast.contains("Won't show"), let id = lastHiddenTmdbId {
            Task {
                try? await RecommendationsAPI.unhideMovie(tmdbId: id)
            }
            lastHiddenTmdbId = nil
        }
    }
}

private struct WatchlistItem: Identifiable {
    let tmdbId: Int
    var id: Int {
        tmdbId
    }
}
