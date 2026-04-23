import SwiftUI

struct ReelsFeedView: View {
    let movies: [ReelMovie]
    var groupContext: ReelCardView.GroupContext?
    var isTabVisible: Bool = true
    var onLoadMore: (() async -> Void)?
    var onRefresh: (() async -> Void)?
    var externalCurrentId: Binding<Int?>?

    @State private var internalCurrentId: Int?
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var watchlistTmdbId: Int?
    @State private var addedToWatchlist: Set<Int> = []
    @State private var lastWatchlistedTmdbId: Int?
    @State private var lastHiddenTmdbId: Int?
    @State private var detailMovie: ReelMovie?

    private var currentIdBinding: Binding<Int?> {
        externalCurrentId ?? $internalCurrentId
    }

    private var currentId: Int? {
        currentIdBinding.wrappedValue
    }

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
                                    lastWatchlistedTmdbId = movie.tmdbId
                                }
                                showToast(msg)
                                advanceToNext(from: movie.tmdbId)
                            },
                            onRated: { _ in },
                            onShowDetail: {
                                detailMovie = movie
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
            .scrollPosition(id: currentIdBinding)
            .scrollIndicators(.hidden)
            .refreshable {
                await onRefresh?()
            }
        }
        .onChange(of: currentId) { _, newId in
            guard let newId else { return }
            if let idx = movies.firstIndex(where: {
                $0.tmdbId == newId
            }), idx >= movies.count - 4 {
                Task { await onLoadMore?() }
            }
        }
        .onChange(of: movies) { oldMovies, newMovies in
            let isAppend = !oldMovies.isEmpty
                && newMovies.count > oldMovies.count
                && newMovies.prefix(oldMovies.count).map(\.tmdbId) == oldMovies.map(\.tmdbId)
            if !isAppend {
                currentIdBinding.wrappedValue = newMovies.first?.tmdbId
            }
        }
        .onAppear {
            if currentId == nil, let first = movies.first {
                currentIdBinding.wrappedValue = first.tmdbId
            }
        }
        .navigationDestination(item: $detailMovie) { movie in
            MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
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

    // MARK: - Navigation

    private func advanceToNext(from tmdbId: Int) {
        guard let idx = movies.firstIndex(where: { $0.tmdbId == tmdbId }),
              idx + 1 < movies.count
        else { return }
        let nextId = movies[idx + 1].tmdbId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.35)) {
                currentIdBinding.wrappedValue = nextId
            }
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
            if let id = lastWatchlistedTmdbId {
                watchlistTmdbId = id
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
