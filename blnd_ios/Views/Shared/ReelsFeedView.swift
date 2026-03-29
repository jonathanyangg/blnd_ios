import SwiftUI

struct ReelsFeedView: View {
    let movies: [ReelMovie]
    var groupContext: ReelCardView.GroupContext?
    var onLoadMore: (() async -> Void)?
    var onRefresh: (() async -> Void)?

    @State private var currentId: Int?
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
        .onChange(of: movies) { _, newMovies in
            if currentId == nil, let first = newMovies.first {
                currentId = first.tmdbId
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
