import SwiftUI

struct ReelsFeedView: View {
    let movies: [ReelMovie]
    var groupContext: ReelCardView.GroupContext?
    var onLoadMore: (() async -> Void)?
    var onRefresh: (() async -> Void)?

    private var cache: UserActionCache {
        UserActionCache.shared
    }

    @State private var currentId: Int?
    @State private var prefetchTask: Task<Void, Never>?
    @State private var toastMessage: String?
    @State private var showWatchlistPicker = false
    @State private var watchlistTmdbId: Int?
    @State private var addedToWatchlist: Set<Int> = []

    var body: some View {
        GeometryReader { geo in
            let cardHeight = geo.size.height

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(
                        Array(movies.enumerated()),
                        id: \.element.id
                    ) { index, movie in
                        ReelCardView(
                            movie: movie,
                            isActive: movie.tmdbId == currentId,
                            groupContext: groupContext,
                            onWatchlistAdded: { msg in
                                addedToWatchlist.insert(
                                    movie.tmdbId
                                )
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
                        .onAppear {
                            if index >= movies.count - 4 {
                                Task {
                                    await onLoadMore?()
                                }
                            }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentId)
            .scrollIndicators(.hidden)
        }
        .onChange(of: currentId) { _, newId in
            if let newId {
                prefetchNeighbors(for: newId)
            }
        }
        .onChange(of: movies) { _, newMovies in
            if currentId == nil, let first = newMovies.first {
                currentId = first.tmdbId
            }
        }
        .onAppear {
            if currentId == nil, let first = movies.first {
                currentId = first.tmdbId
                prefetchNeighbors(for: first.tmdbId)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = toastMessage {
                ReelToast(
                    message: toast,
                    actionLabel: toast.contains("Watchlist")
                        ? "Change" : nil,
                    onAction: {
                        if let curId = currentId {
                            watchlistTmdbId = curId
                            showWatchlistPicker = true
                        }
                        toastMessage = nil
                    }
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
        .sheet(isPresented: $showWatchlistPicker) {
            if let tid = watchlistTmdbId {
                WatchlistPickerSheet(
                    tmdbId: tid,
                    isWatched: false,
                    isInPersonalWatchlist: addedToWatchlist
                        .contains(tid)
                ) { _ in }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AppTheme.card)
            }
        }
    }

    // MARK: - Prefetch

    private func prefetchNeighbors(for tmdbId: Int) {
        prefetchTask?.cancel()
        prefetchTask = Task(priority: .utility) {
            guard let idx = movies.firstIndex(where: {
                $0.tmdbId == tmdbId
            }) else { return }

            let low = max(0, idx - 3)
            let high = min(movies.count - 1, idx + 3)
            let window = movies[low ... high]

            let idsToFetch = await MainActor.run {
                window.filter { cache.shouldFetchDetail($0.tmdbId) }
                    .map(\.tmdbId)
            }

            await withTaskGroup(
                of: (Int, MovieResponse?).self
            ) { group in
                for tmdbId in idsToFetch {
                    group.addTask {
                        do {
                            let detail =
                                try await MoviesAPI.getMovie(
                                    tmdbId: tmdbId
                                )
                            return (tmdbId, detail)
                        } catch {
                            return (tmdbId, nil)
                        }
                    }
                }
                for await (tid, detail) in group {
                    if Task.isCancelled { break }
                    if let detail {
                        await cache.cacheMovieDetail(detail)
                    } else {
                        await cache.clearPendingDetail(tid)
                    }
                }
            }
        }
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
