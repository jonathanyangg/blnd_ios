import SwiftUI

private enum ProfileTab: String, CaseIterable {
    case watched = "Watched"
    case watchlist = "Watchlist"
    case taste = "Taste"
}

struct ProfileView: View {
    @Environment(AuthState.self) private var authState
    @Environment(TabState.self) private var tabState
    @State private var showSettings = false
    @State private var showImportContext = false
    @State private var selectedTab: ProfileTab = .watched
    @Namespace private var profileTabNamespace

    @State private var watchedMovies: [WatchedMovieResponse] = []
    @State private var watchlistMovies: [WatchlistMovieResponse] = []
    @State private var watchedTotal = 0
    @State private var watchlistTotal = 0
    @State private var isLoadingWatched = false
    @State private var isLoadingWatchlist = false
    @State private var friendsCount = 0
    @State private var groupsCount = 0
    @State private var genreTaste: GenreTasteResponse?
    @State private var isLoadingTaste = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    settingsRow
                    userInfo
                    StatsRow(items: [
                        StatItem(label: "Watched", value: watchedTotal, onTap: nil),
                        StatItem(label: "Watchlist", value: watchlistTotal, onTap: nil),
                        StatItem(
                            label: "Friends",
                            value: friendsCount,
                            onTap: { tabState.switchTab(1) }
                        ),
                        StatItem(
                            label: "Blends",
                            value: groupsCount,
                            onTap: { tabState.switchTab(2) }
                        ),
                    ])
                    tabPicker
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    switch selectedTab {
                    case .watched:
                        watchedGrid
                    case .watchlist:
                        watchlistGrid
                    case .taste:
                        tasteContent
                    }
                }
            }
            .background(AppTheme.background)
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(isPresented: $showImportContext) {
                ImportContextView()
            }
            .task {
                async let watched: () = loadWatched()
                async let watchlist: () = loadWatchlist()
                async let counts: () = loadCounts()
                async let taste: () = loadTaste()
                _ = await (watched, watchlist, counts, taste)
            }
        }
    }

    // MARK: - Settings

    private var settingsRow: some View {
        HStack {
            Button {
                showImportContext = true
            } label: {
                HStack(spacing: 6) {
                    Image("letterboxd-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text("Import")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(AppTheme.textDim)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.textDim)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - User Info

    private var userInfo: some View {
        VStack(spacing: 0) {
            AvatarView(url: authState.currentUser?.avatarUrl, size: 80)
                .padding(.bottom, 12)

            Text(authState.currentUser?.displayName ?? authState.currentUser?.username ?? "User")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("@\(authState.currentUser?.username ?? "")")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 24) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(
                                size: 15,
                                weight: selectedTab == tab ? .bold : .medium
                            ))
                            .foregroundStyle(
                                selectedTab == tab ? .white : AppTheme.textMuted
                            )

                        if selectedTab == tab {
                            Rectangle()
                                .fill(.white)
                                .frame(height: 2)
                                .matchedGeometryEffect(
                                    id: "profileUnderline",
                                    in: profileTabNamespace
                                )
                        } else {
                            Rectangle()
                                .fill(.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Watched Grid

    private var watchedGrid: some View {
        Group {
            if isLoadingWatched {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 40)
            } else if watchedMovies.isEmpty {
                emptyState(message: "No watched movies yet")
            } else {
                PosterGrid {
                    ForEach(watchedMovies) { movie in
                        NavigationLink {
                            MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
                        } label: {
                            PosterTile(posterPath: movie.posterPath, rating: movie.rating)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Watchlist Grid

    private var watchlistGrid: some View {
        Group {
            if isLoadingWatchlist {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 40)
            } else if watchlistMovies.isEmpty {
                emptyState(message: "Your watchlist is empty")
            } else {
                PosterGrid {
                    ForEach(watchlistMovies) { movie in
                        NavigationLink {
                            MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
                        } label: {
                            PosterTile(posterPath: movie.posterPath, rating: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Taste Content

    private var tasteContent: some View {
        Group {
            if isLoadingTaste {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 40)
            } else if let taste = genreTaste, taste.totalRated >= 5 {
                VStack(spacing: 16) {
                    RadarChartView(
                        scores: taste.genres.map(\.score),
                        labels: taste.genres.map(\.name)
                    )
                    .frame(width: 280, height: 280)
                    .padding(.top, 8)

                    Text("Based on \(taste.totalRated) rated movies")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textDim)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.textDim)

                    Text("Rate at least 5 movies to see your taste profile")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
        }
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    // MARK: - Data Loading

    private func loadWatched() async {
        isLoadingWatched = true
        do {
            let response = try await TrackingAPI.getWatchHistory(limit: 50)
            watchedMovies = response.results
            watchedTotal = response.total
        } catch is CancellationError {
            return
        } catch {
            print("[ProfileView] loadWatched error: \(error)")
        }
        isLoadingWatched = false
    }

    private func loadCounts() async {
        let cache = UserActionCache.shared
        await cache.fetchFriends()
        let groups = await cache.fetchGroups()
        friendsCount = cache.friends.count
        groupsCount = groups.count
    }

    private func loadWatchlist() async {
        isLoadingWatchlist = true
        do {
            let response = try await TrackingAPI.getWatchlist(limit: 50)
            watchlistMovies = response.results
            watchlistTotal = response.total
        } catch is CancellationError {
            return
        } catch {
            print("[ProfileView] loadWatchlist error: \(error)")
        }
        isLoadingWatchlist = false
    }

    private func loadTaste() async {
        isLoadingTaste = true
        do {
            genreTaste = try await ProfileAPI.getGenreTaste()
        } catch is CancellationError {
            return
        } catch {
            print("[ProfileView] loadTaste error: \(error)")
        }
        isLoadingTaste = false
    }
}

#Preview {
    ProfileView()
        .environment(AuthState())
        .environment(TabState())
}
