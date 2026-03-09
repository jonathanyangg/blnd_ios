import SwiftUI

private enum ProfileTab: String, CaseIterable {
    case watched = "Watched"
    case watchlist = "Watchlist"
}

struct ProfileView: View {
    @Environment(AuthState.self) private var authState
    @Environment(TabState.self) private var tabState
    @State private var showSettings = false
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

    private let posterColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    settingsRow
                    userInfo
                    statsRow
                    tabPicker
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    switch selectedTab {
                    case .watched:
                        watchedGrid
                    case .watchlist:
                        watchlistGrid
                    }
                }
            }
            .background(AppTheme.background)
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                await authState.fetchCurrentUser()
                async let watched: () = loadWatched()
                async let watchlist: () = loadWatchlist()
                async let counts: () = loadCounts()
                _ = await (watched, watchlist, counts)
            }
        }
    }

    // MARK: - Settings

    private var settingsRow: some View {
        HStack {
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

    // MARK: - Stats

    private var statsRow: some View {
        HStack {
            statItem(value: "\(watchedTotal)", label: "Watched")
            statItem(value: "\(watchlistTotal)", label: "Watchlist")
            Button { tabState.selectedTab = 1 } label: {
                statItem(value: "\(friendsCount)", label: "Friends")
            }
            .buttonStyle(.plain)
            Button { tabState.selectedTab = 2 } label: {
                statItem(value: "\(groupsCount)", label: "Blends")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            Divider().background(AppTheme.cardSecondary)
        }
        .overlay(alignment: .bottom) {
            Divider().background(AppTheme.cardSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
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
                LazyVGrid(columns: posterColumns, spacing: 8) {
                    ForEach(watchedMovies) { movie in
                        NavigationLink {
                            MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
                        } label: {
                            posterTile(
                                path: movie.posterPath,
                                rating: movie.rating
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
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
                LazyVGrid(columns: posterColumns, spacing: 8) {
                    ForEach(watchlistMovies) { movie in
                        NavigationLink {
                            MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
                        } label: {
                            posterTile(path: movie.posterPath, rating: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Poster Tile

    private func posterTile(path: String?, rating: Double?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let path, let url = URL(string: "https://image.tmdb.org/t/p/w342\(path)") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(2 / 3, contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.posterGradient)
                            .aspectRatio(2 / 3, contentMode: .fill)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.posterGradient)
                    .aspectRatio(2 / 3, contentMode: .fill)
            }

            if let rating {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                    Text(rating.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", rating)
                        : String(format: "%.1f", rating))
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(.black.opacity(0.7))
                .clipShape(Capsule())
                .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        do {
            async let friends = FriendsAPI.listFriends()
            async let groups = GroupsAPI.listGroups()
            let (friendsResult, groupsResult) = try await (friends, groups)
            friendsCount = friendsResult.friends.count
            groupsCount = groupsResult.groups.count
        } catch is CancellationError {
            return
        } catch {
            print("[ProfileView] loadCounts error: \(error)")
        }
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
}

#Preview {
    ProfileView()
        .environment(AuthState())
        .environment(TabState())
}
