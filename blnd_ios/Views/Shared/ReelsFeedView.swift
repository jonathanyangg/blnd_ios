import SwiftUI

struct ReelsFeedView: View {
    let movies: [ReelMovie]
    var feed: Analytics.FeedSource = .fyp
    var isTabVisible: Bool = true
    var onLoadMore: (() async -> Void)?
    var onRefresh: (() async -> Void)?
    var externalCurrentId: Binding<Int?>?
    @State private var internalCurrentId: Int?
    @State private var toastMessage: String?
    @State private var mutationError: UserFacingError?
    @State private var mutationRetry: (() -> Void)?
    @State private var toastTask: Task<Void, Never>?
    @State private var watchlistTmdbId: Int?
    @State private var lastNotForMeTmdbId: Int?
    @State private var detailMovie: ReelMovie?
    @State private var selectedFriend: FriendResponse?

    private var currentIdBinding: Binding<Int?> {
        externalCurrentId ?? $internalCurrentId
    }

    private var currentId: Int? {
        currentIdBinding.wrappedValue
    }

    var body: some View {
        GeometryReader { geo in
            // The floating tab bar overlaps this container. A page that
            // includes that overlap leaves the next movie peeking under the bar.
            // shortcut: iOS 26's floating tab bar overlaps the page when
            // safeAreaInsets.bottom is 0. 80pt matches that bar on a Pro Max.
            let overlap = max(geo.safeAreaInsets.bottom, 80)
            let cardHeight = max(geo.size.height - overlap, 1)

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(
                        Array(movies.enumerated()),
                        id: \.element.id
                    ) { index, movie in
                        ReelCardView(
                            movie: movie,
                            isActive: movie.tmdbId == currentId
                                && isTabVisible,
                            position: index,
                            feed: feed,
                            onSwipeResult: { result in
                                switch result {
                                case .hidden:
                                    lastNotForMeTmdbId = movie.tmdbId
                                    showToast("Won't show again")
                                    advanceToNext(from: movie.tmdbId)
                                case .interested:
                                    showToast("Interested")
                                    advanceToNext(from: movie.tmdbId)
                                case .interestFailed:
                                    showToast("Couldn't save interest")
                                case .notForMeFailed:
                                    showToast("Couldn't save that")
                                }
                            },
                            onRequestWatchlist: {
                                watchlistTmdbId = movie.tmdbId
                            },
                            onRated: { _ in },
                            onMutationFailed: { copy, retry in
                                noteMutationFailure(copy, retry: retry, tmdbId: movie.tmdbId)
                            },
                            onShowDetail: {
                                detailMovie = movie
                            },
                            onShowFriend: { friend in
                                selectedFriend = friend
                            }
                        )
                        .frame(height: cardHeight)
                        .id(movie.tmdbId)
                        .scrollTransition(.interactive, axis: .vertical) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.7)
                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(
                .viewAligned(limitBehavior: .alwaysByOne)
            )
            .scrollPosition(id: currentIdBinding)
            .scrollIndicators(.hidden)
            .frame(height: cardHeight)
            .clipped()
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
            MovieDetailView(tmdbId: movie.tmdbId, title: movie.title, source: .reels)
        }
        .navigationDestination(item: $selectedFriend) { friend in
            FriendProfileView(friend: friend)
        }
        .overlay(alignment: .bottom) {
            if let mutationError {
                ErrorToast(message: mutationError, retry: mutationRetry, onDismiss: {
                    self.mutationError = nil
                    mutationRetry = nil
                })
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            } else if let toast = toastMessage {
                ReelToast(
                    message: toast,
                    actionLabel: toastActionLabel(toast),
                    onAction: { handleToastAction(toast) }
                )
                .accessibilityIdentifier("reel.toast")
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
                isInPersonalWatchlist: UserActionCache.shared
                    .isWatchlisted(item.tmdbId)
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

    private func noteMutationFailure(
        _ copy: UserFacingError,
        retry: @escaping () -> Void,
        tmdbId: Int
    ) {
        toastMessage = nil
        if lastNotForMeTmdbId == tmdbId {
            currentIdBinding.wrappedValue = tmdbId
            lastNotForMeTmdbId = nil
        }
        mutationError = copy
        mutationRetry = retry
    }

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
        if toast.contains("Won't show") { return "Undo" }
        return nil
    }

    private func handleToastAction(_ toast: String) {
        toastMessage = nil
        if toast.contains("Won't show"), let id = lastNotForMeTmdbId {
            Task {
                try? await RecommendationsAPI.unmarkNotForMe(tmdbId: id)
            }
            lastNotForMeTmdbId = nil
        }
    }
}

private struct WatchlistItem: Identifiable {
    let tmdbId: Int
    var id: Int {
        tmdbId
    }
}
