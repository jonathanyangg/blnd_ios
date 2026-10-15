import SwiftUI

struct FriendsListView: View {
    @State private var friends: [FriendResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddFriend = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Friends")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    ErrorStateView(message: error) {
                        Task { await loadData() }
                    }
                    .padding(.top, 40)
                } else {
                    friendsTab
                }
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showAddFriend) {
            NavigationStack {
                AddFriendView()
            }
            .presentationBackground(AppTheme.background)
        }
        .task { await loadData() }
        .refreshable {
            UserActionCache.shared.invalidateFriends()
            await loadData()
        }
        .onChange(of: showAddFriend) {
            if !showAddFriend {
                UserActionCache.shared.invalidateFriends()
                Task { await loadData() }
            }
        }
    }

    // MARK: - Friends Tab

    @ViewBuilder
    private var friendsTab: some View {
        if friends.isEmpty {
            emptyState(
                icon: "person.2",
                title: "No friends yet",
                subtitle: "Add friends to see them here"
            )
        } else {
            ForEach(friends) { friend in
                NavigationLink {
                    FriendProfileView(friend: friend)
                } label: {
                    FriendRow(friend: friend)
                }
                .buttonStyle(.plain)

                Divider()
                    .background(AppTheme.cardSecondary)
                    .padding(.horizontal, 24)
            }
        }
    }

    private func emptyState(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.textDim)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(.top, 60)
    }

    // MARK: - Actions

    private func loadData() async {
        errorMessage = nil
        let cache = UserActionCache.shared
        await cache.fetchFriends()
        friends = cache.friends
        if friends.isEmpty, !cache.didLoadFriends {
            errorMessage = "Could not load friends"
        }
        isLoading = false
    }
}

// MARK: - Friend Row

private struct FriendRow: View {
    let friend: FriendResponse

    var body: some View {
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
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
    }
}

// MARK: - Incoming Request Row

struct IncomingRequestRow: View {
    let request: FriendRequestResponse
    let onAccept: () async -> Void
    let onReject: () async -> Void
    @State private var isActing = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: request.requester.avatarUrl)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    request.requester.displayName
                        ?? request.requester.username
                )
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                Text("@\(request.requester.username)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            if isActing {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            } else {
                Button {
                    isActing = true
                    Task {
                        await onAccept()
                        isActing = false
                    }
                } label: {
                    Text("Accept")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white)
                        .clipShape(Capsule())
                }

                Button {
                    isActing = true
                    Task {
                        await onReject()
                        isActing = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 24)
    }
}

// MARK: - Outgoing Request Row

struct OutgoingRequestRow<Destination: View>: View {
    let request: FriendRequestResponse
    let destination: Destination
    let onWithdraw: () async -> Void
    @State private var showWithdrawAlert = false
    @State private var isWithdrawing = false

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                destination
            } label: {
                HStack(spacing: 12) {
                    AvatarView(url: request.addressee.avatarUrl)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            request.addressee.displayName
                                ?? request.addressee.username
                        )
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        Text("@\(request.addressee.username)")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isWithdrawing {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            } else {
                Button {
                    showWithdrawAlert = true
                } label: {
                    Text("Pending")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textDim)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.card)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 24)
        .alert("Withdraw request?", isPresented: $showWithdrawAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Withdraw", role: .destructive) {
                isWithdrawing = true
                Task {
                    await onWithdraw()
                    isWithdrawing = false
                }
            }
        } message: {
            Text("Cancel your friend request to @\(request.addressee.username)?")
        }
    }
}
