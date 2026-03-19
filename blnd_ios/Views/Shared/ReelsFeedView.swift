import SwiftUI

struct ReelsFeedView: View {
    let movies: [ReelMovie]
    var groupContext: ReelCardView.GroupContext?
    var onLoadMore: (() async -> Void)?
    var onRefresh: (() async -> Void)?

    @State private var currentId: Int?
    @State private var detailCache: [Int: MovieResponse] = [:]
    @State private var prefetchTask: Task<Void, Never>?
    @State private var toastMessage: String?
    @State private var showWatchlistPicker = false
    @State private var watchlistTmdbId: Int?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(
                    Array(movies.enumerated()),
                    id: \.element.id
                ) { index, movie in
                    ReelCardView(
                        movie: movie,
                        isActive: movie.tmdbId == currentId,
                        fullDetail: detailCache[movie.tmdbId],
                        groupContext: groupContext,
                        onWatchlistAdded: { message in
                            showToast(message)
                        },
                        onRated: { rating in
                            showToast(
                                "Rated \(String(format: "%.1f", rating)) stars"
                            )
                        }
                    )
                    .id(movie.tmdbId)
                    .onAppear {
                        if index >= movies.count - 4 {
                            Task { await onLoadMore?() }
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentId)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
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
        .overlay(alignment: .top) {
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
                .padding(.top, 100)
                .transition(
                    .move(edge: .top).combined(with: .opacity)
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: toastMessage)
        .sheet(isPresented: $showWatchlistPicker) {
            if let tid = watchlistTmdbId {
                WatchlistPickerSheet(
                    tmdbId: tid,
                    isWatched: false,
                    isInPersonalWatchlist: false
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

            await withTaskGroup(of: (Int, MovieResponse?).self) { group in
                for item in window where detailCache[item.tmdbId] == nil {
                    group.addTask {
                        do {
                            let detail = try await MoviesAPI.getMovie(
                                tmdbId: item.tmdbId
                            )
                            return (item.tmdbId, detail)
                        } catch {
                            return (item.tmdbId, nil)
                        }
                    }
                }
                for await (tid, detail) in group {
                    if let detail, !Task.isCancelled {
                        detailCache[tid] = detail
                    }
                }
            }
        }
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
