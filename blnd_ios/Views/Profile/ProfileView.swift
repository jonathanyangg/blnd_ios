import SwiftUI

private enum ProfileTab: String, CaseIterable {
    case watched = "Watched"
    case diary = "Diary"
    case watchlist = "Watchlist"
    case taste = "Taste"
}

struct ProfileView: View {
    @Environment(AuthState.self) private var authState
    @Environment(TabState.self) private var tabState
    @State private var showSettings = false
    @State private var showImportContext = false
    @State private var showNotifications = false
    @State private var unreadCount = 0
    @State private var showFullAvatar = false
    @State private var showPaywall = false
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

    @State private var watchedSort: MovieSortOption = .dateDesc
    @State private var watchlistSort: MovieSortOption = .dateDesc
    @State private var diaryReload = 0

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

                    if !authState.isPremium {
                        premiumUpsellCard
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                    }

                    tabPicker
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    switch selectedTab {
                    case .watched:
                        watchedGrid
                    case .diary:
                        WatchTimelineScreen(
                            source: .own,
                            embedsInParentScroll: true,
                            emptyTitle: "Your diary is empty",
                            emptyMessage: "Rate a movie and tag the friends you watched it with.",
                            detailSource: .profile,
                            reloadToken: diaryReload
                        )
                    case .watchlist:
                        watchlistGrid
                    case .taste:
                        tasteContent
                    }
                }
            }
            .background(AppTheme.background)
            .refreshable { await refreshAll() }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(isPresented: $showImportContext) {
                ImportContextView()
            }
            .navigationDestination(isPresented: $showNotifications) {
                ActivityFeedView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(source: .manual)
                    .environment(authState)
            }
            .fullScreenCover(isPresented: $showFullAvatar) {
                FullAvatarView(url: authState.currentUser?.avatarUrl) {
                    showFullAvatar = false
                }
            }
            .task {
                async let watched: () = loadWatched()
                async let watchlist: () = loadWatchlist()
                async let counts: () = loadCounts()
                async let taste: () = loadTaste()
                async let unread: () = loadUnreadCount()
                _ = await (watched, watchlist, counts, taste, unread)
            }
            .onChange(of: showNotifications) {
                if !showNotifications {
                    // Refresh unread count when coming back from notifications
                    Task { await loadUnreadCount() }
                }
            }
            .onChange(of: watchedSort) { Task { await loadWatched() } }
            .onChange(of: watchlistSort) { Task { await loadWatchlist() } }
        }
    }

    private var currentSortBinding: Binding<MovieSortOption> {
        selectedTab == .watched
            ? $watchedSort
            : $watchlistSort
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
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textDim)
                    if unreadCount > 0 {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.textDim)
            }
            .accessibilityIdentifier("profile.settings")
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - User Info

    private var userInfo: some View {
        VStack(spacing: 0) {
            Button { showFullAvatar = true } label: {
                AvatarView(url: authState.currentUser?.avatarUrl, size: 80, isPremium: authState.isPremium)
            }
            .padding(.bottom, 12)

            Text(authState.currentUser?.displayName ?? authState.currentUser?.username ?? "User")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("@\(authState.currentUser?.username ?? "")")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)

            if authState.isPremium {
                BlndPlusBadge(size: 12)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .overlay(
                        Capsule().stroke(AppTheme.border, lineWidth: 1)
                    )
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Premium Upsell

    private var premiumUpsellCard: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.premiumGoldGradient)

                VStack(alignment: .leading, spacing: 2) {
                    BlndPlusBadge(size: 13)
                    Text("AI search, larger groups & more")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()

                Text("Get")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppTheme.premiumGoldGradient)
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.premiumGoldGradient.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            sortMenu(
                sort: currentSortBinding,
                allowsRating: selectedTab == .watched
            )
            .disabled(selectedTab == .taste || selectedTab == .diary)
            .padding(.trailing, 16)
            // Center the icon with the tab text (the tab VStack adds an
            // underline below its text, which pushes the icon ~4pt low).
            .offset(y: -4)
            .transaction { $0.animation = nil }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
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
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func sortMenu(sort: Binding<MovieSortOption>, allowsRating: Bool) -> some View {
        let options = MovieSortOption.allCases.filter { option in
            if option == .titleAsc || option == .titleDesc { return false }
            if !allowsRating, !option.appliesToWatchlist { return false }
            return true
        }
        return Menu {
            ForEach(options) { option in
                Button {
                    sort.wrappedValue = option
                } label: {
                    if sort.wrappedValue == option {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Poster Grids

extension ProfileView {
    var watchedGrid: some View {
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
                            MovieDetailView(tmdbId: movie.tmdbId, title: movie.title, source: .profile)
                        } label: {
                            PosterTile(posterPath: movie.posterPath, rating: movie.rating)
                        }
                        .buttonStyle(.plain)
                        .id(movie.tmdbId)
                    }
                }
            }
        }
    }

    var watchlistGrid: some View {
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
                            MovieDetailView(tmdbId: movie.tmdbId, title: movie.title, source: .watchlist)
                        } label: {
                            PosterTile(posterPath: movie.posterPath, rating: nil)
                        }
                        .buttonStyle(.plain)
                        .id(movie.tmdbId)
                    }
                }
            }
        }
    }
}

// MARK: - Content Sections

extension ProfileView {
    var tasteContent: some View {
        Group {
            if isLoadingTaste {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 40)
            } else if let taste = genreTaste, taste.totalRated >= 5 {
                VStack(spacing: 4) {
                    RadarChartView(
                        scores: taste.genres.map(\.score),
                        labels: taste.genres.map(\.name)
                    )
                    .frame(width: 280, height: 280)

                    Text("Based on \(taste.totalRated) rated movies")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textDim)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 32)
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

    func emptyState(message: String) -> some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }
}

// MARK: - Data Loading

extension ProfileView {
    func loadWatched() async {
        isLoadingWatched = true
        do {
            let response = try await TrackingAPI.getWatchHistory(
                limit: 50,
                sort: watchedSort
            )
            watchedMovies = response.results
            watchedTotal = response.total
        } catch is CancellationError {
            return
        } catch { /* Non-critical — empty state shown */ }
        isLoadingWatched = false
    }

    func loadCounts() async {
        let cache = UserActionCache.shared
        await cache.fetchFriends()
        let groups = await cache.fetchGroups()
        friendsCount = cache.friends.count
        groupsCount = groups.count
    }

    func loadWatchlist() async {
        isLoadingWatchlist = true
        do {
            let response = try await TrackingAPI.getWatchlist(
                limit: 50,
                sort: watchlistSort
            )
            watchlistMovies = response.results
            watchlistTotal = response.total
        } catch is CancellationError {
            return
        } catch { /* Non-critical — empty state shown */ }
        isLoadingWatchlist = false
    }

    func loadUnreadCount() async {
        do {
            let response = try await NotificationAPI.getInbox(limit: 1)
            unreadCount = response.unreadCount
        } catch {
            // Non-critical
        }
    }

    func loadTaste() async {
        isLoadingTaste = true
        do {
            genreTaste = try await ProfileAPI.getGenreTaste()
        } catch is CancellationError {
            return
        } catch { /* Non-critical — "rate more movies" fallback shown */ }
        isLoadingTaste = false
    }

    func refreshAll() async {
        UserActionCache.shared.invalidateGroups()
        UserActionCache.shared.invalidateFriends()
        async let watched: () = loadWatched()
        async let watchlist: () = loadWatchlist()
        async let counts: () = loadCounts()
        async let taste: () = loadTaste()
        async let unread: () = loadUnreadCount()
        _ = await (watched, watchlist, counts, taste, unread)
        diaryReload += 1
        await authState.fetchCurrentUser()
    }
}

#Preview {
    ProfileView()
        .environment(AuthState())
        .environment(TabState())
}
