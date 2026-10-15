import SwiftUI

/// One movie for right now: a reason, a re-roll, and a watchlist action.
struct FindMovieNowView: View {
    var onFinished: (() -> Void)?
    var previewSaved = false
    var lovedTitles: [String] = []

    @Environment(\.dismiss) private var dismiss
    @State private var pick: NowPickResponse?
    @State private var excluded: [Int]
    @State private var isLoading = true
    @State private var isOnWatchlist = false
    @State private var isSavingWatchlist = false
    @State private var errorMessage: String?

    init(
        onFinished: (() -> Void)? = nil,
        previewSaved: Bool = false,
        previewExcluded: [Int] = [],
        lovedTitles: [String] = []
    ) {
        self.onFinished = onFinished
        self.previewSaved = previewSaved
        self.lovedTitles = lovedTitles
        _excluded = State(initialValue: previewExcluded)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if let pick, !isLoading {
                result(pick)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if let errorMessage {
                errorState(errorMessage)
            } else {
                loadingState
            }
        }
        .accessibilityIdentifier("find-movie-now")
        .task { await load() }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white)
            Text("Finding one movie")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier("find-movie-now.loading")
    }

    private func result(_ pick: NowPickResponse) -> some View {
        let movie = pick.movie
        return VStack(spacing: 0) {
            topBar
            Spacer(minLength: 12)
            Text(pick.reason)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .accessibilityIdentifier("find-movie-now.reason")
            MovieCard(
                tmdbId: movie.tmdbId,
                title: movie.title,
                year: movie.yearString,
                posterPath: movie.posterPath,
                width: 210,
                height: 315,
                glow: true,
                scorePercent: movie.scorePercent
            )
            .padding(.top, 20)
            .accessibilityIdentifier("find-movie-now.poster")
            if let meta = metaLine(movie) {
                Text(meta)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 8)
            }
            actionRow
                .padding(.top, 24)
                .padding(.horizontal, 24)
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.destructive)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 24)
            }
            if onFinished != nil {
                AppButton(label: "This one's mine") {
                    onFinished?()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .accessibilityIdentifier("find-movie-now.done")
            }
            Spacer(minLength: 20)
        }
        .id(movie.tmdbId)
    }

    private var topBar: some View {
        HStack {
            Text("Find a movie now")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
            if onFinished == nil {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.card)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("find-movie-now.close")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                Task { await reroll() }
            } label: {
                Label("Re-roll", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            }
            .disabled(isLoading)
            .accessibilityIdentifier("find-movie-now.reroll")

            Button {
                Task { await toggleWatchlist() }
            } label: {
                Label(
                    isOnWatchlist ? "On your list" : "Watchlist",
                    systemImage: isOnWatchlist ? "bookmark.fill" : "bookmark"
                )
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(isOnWatchlist ? .black : .white)
                .background(isOnWatchlist ? Color.white : AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            }
            .disabled(isSavingWatchlist)
            .accessibilityIdentifier("find-movie-now.watchlist")
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text("No movie right now")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            AppButton(label: "Try again") {
                Task { await load() }
            }
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 24)
    }

    private func metaLine(_ movie: RecommendedMovieResponse) -> String? {
        var parts: [String] = []
        if !movie.yearString.isEmpty { parts.append(movie.yearString) }
        if let runtime = movie.runtimeFormatted { parts.append(runtime) }
        if let genre = movie.genres.first?.name { parts.append(genre) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func load() async {
        guard pick == nil else { return }
        isLoading = true
        errorMessage = nil
        do {
            let next = try await fetch(excluding: excluded)
            apply(next)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func reroll() async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        do {
            let next = try await fetch(excluding: excluded)
            withAnimation(.spring(duration: 0.35)) {
                apply(next)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetch(excluding: [Int]) async throws -> NowPickResponse {
        if UITestLaunch.usesMockNow {
            return NowCatalog.pick(excluding: excluding, lovedTitles: lovedTitles)
        }
        return try await RecommendationsAPI.findNow(genre: nil, exclude: excluding)
    }

    private func apply(_ next: NowPickResponse) {
        let isNewMovie = pick?.movie.tmdbId != next.movie.tmdbId
        pick = next
        if !excluded.contains(next.movie.tmdbId) {
            excluded.append(next.movie.tmdbId)
        }
        isLoading = false
        errorMessage = nil
        if isNewMovie {
            isOnWatchlist = previewSaved
        }
    }

    private func toggleWatchlist() async {
        guard let tmdbId = pick?.movie.tmdbId else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if UITestLaunch.usesMockNow {
            isOnWatchlist.toggle()
            return
        }
        isSavingWatchlist = true
        defer { isSavingWatchlist = false }
        do {
            if isOnWatchlist {
                try await TrackingAPI.removeFromWatchlist(tmdbId: tmdbId)
                isOnWatchlist = false
                Analytics.watchlistRemoved(tmdbId: tmdbId, source: .now)
            } else {
                _ = try await TrackingAPI.addToWatchlist(tmdbId: tmdbId)
                isOnWatchlist = true
                Analytics.watchlistAdded(tmdbId: tmdbId, source: .now)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
