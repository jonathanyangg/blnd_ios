import SwiftUI

enum FriendProfileTab: String, CaseIterable {
    case watched = "Watched"
    case taste = "Taste"
}

struct FriendProfileView: View {
    let friend: FriendResponse

    @State var showRemoveAlert = false
    @State var showBlockAlert = false
    @State var showUnblockAlert = false
    @State var showReportDialog = false
    @State var showReportConfirmation = false
    @State var reportReason: String = ""
    @State var isRemoving = false
    @State var isSendingRequest = false
    @State var isBlocking = false
    @State var isReporting = false
    @State var friendshipAction: String?
    @State var blockOverride: BlockOverride = .none
    @Environment(\.dismiss) var dismiss

    enum BlockOverride {
        case none, blocked, unblocked
    }

    @State var publicProfile: PublicProfileResponse?
    @State var watchedMovies: [PublicWatchedMovieResponse] = []
    @State var watchedTotal = 0
    @State var isLoading = true
    @State var isLoadingMore = false
    @State var watchedGated = false

    @State var selectedTab: FriendProfileTab = .watched
    @State var watchedSort: MovieSortOption = .dateDesc
    @Namespace var friendTabNamespace

    @State var genreTaste: GenreTasteResponse?
    @State var isLoadingTaste = false

    @State var showFriendsList = false
    @State var friendsList: [PublicFriendResponse] = []
    @State var isLoadingFriends = false

    @State var mutualFriends: [MutualFriendResponse] = []
    @State var mutualCount = 0
    @State var showMutualsList = false

    @State var selectedFriendOfFriend: PublicFriendResponse?
    @State var showFullAvatar = false

    var body: some View {
        ScrollView {
            scrollContent
                .padding(.bottom, 32)
                .opacity(publicProfile == nil ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: publicProfile == nil)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: publicProfile == nil)
        .navigationBarBackButtonHidden()
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                profileMenu
            }
        }
        .alert(
            currentStatus == "accepted" ? "Remove Friend" : "Withdraw Request",
            isPresented: $showRemoveAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button(
                currentStatus == "accepted" ? "Remove" : "Withdraw",
                role: .destructive
            ) {
                Task { await removeFriend() }
            }
        } message: {
            Text(
                currentStatus == "accepted"
                    ? "Remove @\(friend.username) from your friends?"
                    : "Withdraw your friend request to @\(friend.username)?"
            )
        }
        .alert("Block @\(friend.username)?", isPresented: $showBlockAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                Task { await blockUser() }
            }
        } message: {
            Text(
                "They won't be able to find you, send you requests, or see your profile. "
                    + "You won't see them either. They'll still appear in any blends you share."
            )
        }
        .alert("Unblock @\(friend.username)?", isPresented: $showUnblockAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Unblock") {
                Task { await unblockUser() }
            }
        } message: {
            Text("They'll be able to find you and send friend requests again.")
        }
        .confirmationDialog(
            "Report @\(friend.username)",
            isPresented: $showReportDialog,
            titleVisibility: .visible
        ) {
            Button("Spam") { submitReport("spam") }
            Button("Harassment or bullying") { submitReport("harassment") }
            Button("Hate speech or symbols") { submitReport("hate") }
            Button("Sexual or inappropriate content") { submitReport("sexual") }
            Button("Impersonation") { submitReport("impersonation") }
            Button("Something else") { submitReport("other") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Reports are reviewed within 24 hours. Offending content "
                    + "will be removed and repeat offenders will be ejected from blnd."
            )
        }
        .alert("Thanks for the report", isPresented: $showReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We'll review this report within 24 hours.")
        }
        .sheet(isPresented: $showFriendsList) {
            FriendsListSheet(friends: friendsList, isLoading: isLoadingFriends) { selected in
                selectedFriendOfFriend = selected
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
        .sheet(isPresented: $showMutualsList) {
            MutualsListSheet(mutuals: mutualFriends) { selected in
                selectedFriendOfFriend = selected
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
        .navigationDestination(item: $selectedFriendOfFriend) { friendOfFriend in
            FriendProfileView(friend: FriendResponse(
                friendshipId: nil,
                id: friendOfFriend.id,
                username: friendOfFriend.username,
                displayName: friendOfFriend.displayName,
                avatarUrl: friendOfFriend.avatarUrl
            ))
        }
        .fullScreenCover(isPresented: $showFullAvatar) {
            FullAvatarView(url: avatarUrl) {
                showFullAvatar = false
            }
        }
    }
}

// MARK: - Profile sections

extension FriendProfileView {
    var scrollContent: some View {
        VStack(spacing: 0) {
            profileHeader

            if let profile = publicProfile {
                statsRowView(profile: profile)
            }

            if !watchedGated, publicProfile != nil {
                tabPicker
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }

            switch selectedTab {
            case .watched:
                watchedSection
            case .taste:
                tasteSection
            }
        }
        .task { await loadData() }
        .onChange(of: showFriendsList) {
            if showFriendsList {
                Task { await loadFriends() }
            }
        }
        .onChange(of: watchedSort) { Task { await reloadWatched() } }
        .onChange(of: selectedTab) {
            if selectedTab == .taste, genreTaste == nil, !isLoadingTaste {
                Task { await loadTaste() }
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            sortMenu
                .disabled(selectedTab == .taste)
                .padding(.trailing, 16)
                .transaction { $0.animation = nil }

            HStack(spacing: 24) {
                ForEach(FriendProfileTab.allCases, id: \.self) { tab in
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
                                        id: "friendTabUnderline",
                                        in: friendTabNamespace
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

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var sortMenu: some View {
        let options = MovieSortOption.allCases.filter {
            $0 != .titleAsc && $0 != .titleDesc
        }
        return Menu {
            ForEach(options) { option in
                Button {
                    watchedSort = option
                } label: {
                    if watchedSort == option {
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

    // MARK: - Taste Section

    @ViewBuilder
    private var tasteSection: some View {
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

                Text("Not enough ratings yet to show a taste profile")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        }
    }

    // MARK: - Profile Header

    private var avatarUrl: String? {
        publicProfile?.avatarUrl ?? friend.avatarUrl
    }

    private var profileHeader: some View {
        VStack(spacing: 0) {
            Button { showFullAvatar = true } label: {
                AvatarView(
                    url: avatarUrl,
                    size: 80,
                    isPremium: publicProfile?.isPremium ?? false
                )
            }
            .padding(.bottom, 12)

            Text(publicProfile?.displayName ?? friend.displayName ?? friend.username)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("@\(friend.username)")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)

            if publicProfile?.isPremium ?? false {
                BlndPlusBadge(size: 11)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.card)
                    .clipShape(Capsule())
                    .padding(.top, 6)
                    .padding(.bottom, 10)
            } else {
                Spacer().frame(height: 16)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private func statsRowView(profile: PublicProfileResponse) -> some View {
        StatsRow(items: [
            StatItem(label: "Watched", value: profile.watchedCount, onTap: nil),
            StatItem(
                label: "Friends",
                value: profile.friendsCount,
                onTap: profile.friendshipStatus == "accepted"
                    ? { showFriendsList = true }
                    : nil
            ),
            StatItem(
                label: "Mutual",
                value: mutualCount,
                onTap: mutualCount > 0 ? { showMutualsList = true } : nil
            ),
        ])
    }

    @ViewBuilder
    private var watchedSection: some View {
        if publicProfile == nil {
            EmptyView()
        } else if watchedGated {
            watchedGatedView
        } else if watchedMovies.isEmpty {
            watchedEmptyView
        } else {
            watchedGridView
        }
    }

    private var watchedGatedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.textDim)
            Text("Add \(friend.username) to see their watched movies")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 40)
    }

    private var watchedEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.textMuted)
            Text("No watched movies yet")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 40)
    }

    private var watchedGridView: some View {
        VStack(spacing: 0) {
            PosterGrid {
                ForEach(watchedMovies) { movie in
                    NavigationLink {
                        MovieDetailView(tmdbId: movie.tmdbId, title: movie.title, source: .friendProfile)
                    } label: {
                        PosterTile(posterPath: movie.posterPath, rating: movie.rating)
                    }
                    .buttonStyle(.plain)
                    .id(movie.tmdbId)
                    .onAppear {
                        if movie.id == watchedMovies.last?.id {
                            Task { await loadMoreWatched() }
                        }
                    }
                }
            }

            if isLoadingMore {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Friendship + Profile Menu

    var currentStatus: String? {
        friendshipAction ?? publicProfile?.friendshipStatus
    }

    var currentFriendshipId: Int? {
        friend.friendshipId ?? publicProfile?.friendshipId
    }

    var isCurrentlyBlocked: Bool {
        switch blockOverride {
        case .blocked: true
        case .unblocked: false
        case .none: publicProfile?.isBlocked ?? false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FriendProfileView(
            friend: FriendResponse(
                friendshipId: 1,
                id: "abc",
                username: "maria",
                displayName: "Maria K.",
                avatarUrl: nil
            )
        )
    }
}
