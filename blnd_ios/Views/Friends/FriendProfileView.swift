import SwiftUI

struct FriendProfileView: View {
    let friend: FriendResponse

    @State var showRemoveAlert = false
    @State var showBlockAlert = false
    @State var showUnblockAlert = false
    @State var isRemoving = false
    @State var isSendingRequest = false
    @State var isBlocking = false
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

    @State var showFriendsList = false
    @State var friendsList: [PublicFriendResponse] = []
    @State var isLoadingFriends = false

    @State var mutualFriends: [MutualFriendResponse] = []
    @State var mutualCount = 0
    @State var showMutualsList = false

    @State var selectedFriendOfFriend: PublicFriendResponse?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile header
                VStack(spacing: 0) {
                    AvatarView(url: publicProfile?.avatarUrl ?? friend.avatarUrl, size: 80)
                        .padding(.bottom, 12)

                    Text(publicProfile?.displayName ?? friend.displayName ?? friend.username)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text("@\(friend.username)")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.bottom, 16)
                }
                .padding(.top, 20)
                .padding(.bottom, 8)

                // Stats row — only render once profile is loaded
                if let profile = publicProfile {
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
                            onTap: mutualCount > 0
                                ? { showMutualsList = true }
                                : nil
                        ),
                    ])
                }

                // Watched grid
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 40)
                } else if watchedGated {
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
                } else if watchedMovies.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 36))
                            .foregroundStyle(AppTheme.textMuted)
                        Text("No watched movies yet")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .padding(.top, 40)
                } else {
                    PosterGrid {
                        ForEach(watchedMovies) { movie in
                            NavigationLink {
                                MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
                            } label: {
                                PosterTile(posterPath: movie.posterPath, rating: movie.rating)
                            }
                            .buttonStyle(.plain)
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
            .padding(.bottom, 32)
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
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
        .sheet(isPresented: $showFriendsList) {
            FriendsListSheet(friends: friendsList, isLoading: isLoadingFriends) { selected in
                selectedFriendOfFriend = selected
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.background)
        }
        .sheet(isPresented: $showMutualsList) {
            MutualsListSheet(mutuals: mutualFriends) { selected in
                selectedFriendOfFriend = selected
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.background)
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
        .onChange(of: showFriendsList) {
            if showFriendsList {
                Task { await loadFriends() }
            }
        }
        .task { await loadData() }
    }

    // MARK: - Friendship + Profile Menu

    var currentStatus: String? {
        friendshipAction ?? publicProfile?.friendshipStatus
    }

    var currentFriendshipId: Int? {
        friend.friendshipId ?? publicProfile?.friendshipId
    }

    private var isCurrentlyBlocked: Bool {
        switch blockOverride {
        case .blocked: true
        case .unblocked: false
        case .none: publicProfile?.isBlocked ?? false
        }
    }

    @ViewBuilder
    private var profileMenu: some View {
        let isSelf = friend.id == (KeychainManager.readString(key: "userId") ?? "")
        if isSelf {
            EmptyView()
        } else if publicProfile == nil {
            EmptyView()
        } else if isBlocking {
            ProgressView().tint(.white).controlSize(.small)
        } else if isCurrentlyBlocked {
            Menu {
                Button("Unblock", role: .destructive) {
                    showUnblockAlert = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
            }
        } else {
            Menu {
                if currentStatus == "accepted" {
                    Button("Remove Friend", role: .destructive) {
                        showRemoveAlert = true
                    }
                } else if currentStatus == "pending" {
                    Button("Withdraw Request", role: .destructive) {
                        showRemoveAlert = true
                    }
                } else {
                    Button {
                        Task { await sendFriendRequest() }
                    } label: {
                        Label("Add Friend", systemImage: "person.badge.plus")
                    }
                }

                Button("Block", role: .destructive) {
                    showBlockAlert = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
            }
        }
    }

    private func sendFriendRequest() async {
        isSendingRequest = true
        do {
            _ = try await FriendsAPI.sendRequest(username: friend.username)
            friendshipAction = "pending"
            PostHogSDK.shared.capture("friend_request_sent")
        } catch { /* Non-critical */ }
        isSendingRequest = false
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
