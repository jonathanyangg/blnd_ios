import SwiftUI

struct FriendProfileView: View {
    let friend: FriendResponse

    @State private var showRemoveAlert = false
    @State private var isRemoving = false
    @Environment(\.dismiss) private var dismiss

    @State private var publicProfile: PublicProfileResponse?
    @State private var watchedMovies: [PublicWatchedMovieResponse] = []
    @State private var watchedTotal = 0
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var watchedGated = false

    @State private var showFriendsList = false
    @State private var friendsList: [PublicFriendResponse] = []
    @State private var isLoadingFriends = false

    @State private var mutualFriends: [MutualFriendResponse] = []
    @State private var mutualCount = 0
    @State private var showMutualsList = false

    @State private var selectedFriendOfFriend: PublicFriendResponse?

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
                        StatItem(label: "Friends", value: profile.friendsCount, onTap: { showFriendsList = true }),
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
                Menu {
                    Button(role: .destructive) {
                        showRemoveAlert = true
                    } label: {
                        Label("Remove Friend", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textDim)
                }
            }
        }
        .alert("Remove Friend", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task { await removeFriend() }
            }
        } message: {
            Text("Remove @\(friend.username) from your friends?")
        }
        .sheet(isPresented: $showFriendsList) {
            FriendsListSheet(friends: friendsList, isLoading: isLoadingFriends) { selected in
                selectedFriendOfFriend = selected
            }
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

    // MARK: - Data loading

    private func loadData() async {
        isLoading = true

        // Profile + mutuals always load (no friendship required)
        async let profile = ProfileAPI.getPublicProfile(userId: friend.id)
        async let mutuals = FriendsAPI.getMutuals(userId: friend.id)
        do {
            let (profileResult, mutualsResult) = try await (profile, mutuals)
            publicProfile = profileResult
            mutualFriends = mutualsResult.mutuals
            mutualCount = mutualsResult.count
        } catch is CancellationError {
            return
        } catch { /* Non-critical */ }

        // Watched movies require friendship — 403 means not friends yet
        do {
            let watchedResult = try await ProfileAPI.getPublicWatched(
                userId: friend.id, limit: 20, offset: 0
            )
            watchedMovies = watchedResult.results
            watchedTotal = watchedResult.total
        } catch is CancellationError {
            return
        } catch {
            // 403 (not friends) or any other error → show gated state
            watchedGated = true
        }

        isLoading = false
    }

    private func loadMoreWatched() async {
        guard !isLoadingMore, watchedMovies.count < watchedTotal else { return }
        isLoadingMore = true
        do {
            let next = try await ProfileAPI.getPublicWatched(
                userId: friend.id,
                limit: 20,
                offset: watchedMovies.count
            )
            watchedMovies.append(contentsOf: next.results)
        } catch is CancellationError {
            return
        } catch { /* Non-critical — pagination stops */ }
        isLoadingMore = false
    }

    private func loadFriends() async {
        isLoadingFriends = true
        friendsList = []
        do {
            let response = try await ProfileAPI.getPublicFriends(userId: friend.id)
            friendsList = response.friends
        } catch is CancellationError {
            return
        } catch { /* Non-critical — empty list shown */ }
        isLoadingFriends = false
    }

    private func removeFriend() async {
        guard let friendshipId = friend.friendshipId else { return }
        isRemoving = true
        do {
            try await FriendsAPI.removeFriend(friendshipId: friendshipId)
            dismiss()
        } catch { /* Non-critical — user can retry */ }
        isRemoving = false
    }
}

// MARK: - FriendsListSheet

private struct FriendsListSheet: View {
    let friends: [PublicFriendResponse]
    let isLoading: Bool
    let onSelectFriend: (PublicFriendResponse) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 40)
                } else if friends.isEmpty {
                    Text("No friends yet")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(friends) { friend in
                            Button {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onSelectFriend(friend)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(url: friend.avatarUrl)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.displayName ?? friend.username)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white)
                                        Text("@\(friend.username)")
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppTheme.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textDim)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 24)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(AppTheme.cardSecondary)
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - MutualsListSheet

private struct MutualsListSheet: View {
    let mutuals: [MutualFriendResponse]
    let onSelectFriend: (PublicFriendResponse) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if mutuals.isEmpty {
                    Text("No mutual friends")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(mutuals) { mutual in
                            Button {
                                dismiss()
                                let asFriend = PublicFriendResponse(
                                    id: mutual.id,
                                    username: mutual.username,
                                    displayName: mutual.displayName,
                                    avatarUrl: mutual.avatarUrl
                                )
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onSelectFriend(asFriend)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(url: mutual.avatarUrl)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mutual.displayName ?? mutual.username)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white)
                                        Text("@\(mutual.username)")
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppTheme.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textDim)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 24)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(AppTheme.cardSecondary)
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Mutual Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
