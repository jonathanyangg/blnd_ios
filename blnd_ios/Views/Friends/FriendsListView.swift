import SwiftUI

struct FriendsListView: View {
    @Environment(TabState.self) private var tabState
    @State private var friends: [FriendResponse] = []
    @State private var pendingRequests: PendingRequestsResponse?
    @State private var isLoading = true
    @State private var showAddFriend = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
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
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Tabs: Friends / Requests
                    FriendsTabPicker(
                        selectedTab: $selectedTab,
                        requestCount: incomingCount
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 40)
                    } else if selectedTab == 0 {
                        friendsTab
                    } else {
                        requestsTab
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
        .id(tabState.navigationReset)
    }

    private var incomingCount: Int {
        pendingRequests?.incoming.count ?? 0
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

    // MARK: - Requests Tab

    @ViewBuilder
    private var requestsTab: some View {
        let incoming = pendingRequests?.incoming ?? []
        let outgoing = pendingRequests?.outgoing ?? []

        if incoming.isEmpty, outgoing.isEmpty {
            emptyState(
                icon: "envelope",
                title: "No pending requests",
                subtitle: "Friend requests will appear here"
            )
        } else {
            if !incoming.isEmpty {
                sectionHeader("Incoming")
                ForEach(incoming) { request in
                    IncomingRequestRow(request: request) {
                        await handleAccept(request)
                    } onReject: {
                        await handleReject(request)
                    }

                    Divider()
                        .background(AppTheme.cardSecondary)
                        .padding(.horizontal, 24)
                }
            }

            if !outgoing.isEmpty {
                sectionHeader("Sent")
                ForEach(outgoing) { request in
                    OutgoingRequestRow(request: request)

                    Divider()
                        .background(AppTheme.cardSecondary)
                        .padding(.horizontal, 24)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.textMuted)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)
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
        let cache = UserActionCache.shared
        await cache.fetchFriends()
        friends = cache.friends
        pendingRequests = cache.pendingRequests
        isLoading = false
    }

    private func handleAccept(_ request: FriendRequestResponse) async {
        do {
            _ = try await FriendsAPI.acceptRequest(
                friendshipId: request.id
            )
            UserActionCache.shared.invalidateFriends()
            await loadData()
            await tabState.refreshPendingCount()
        } catch {
            print("[FriendsListView] Accept failed: \(error)")
        }
    }

    private func handleReject(_ request: FriendRequestResponse) async {
        do {
            _ = try await FriendsAPI.rejectRequest(
                friendshipId: request.id
            )
            UserActionCache.shared.invalidateFriends()
            await loadData()
            await tabState.refreshPendingCount()
        } catch {
            print("[FriendsListView] Reject failed: \(error)")
        }
    }
}

// MARK: - Tab Picker

private struct FriendsTabPicker: View {
    @Binding var selectedTab: Int
    let requestCount: Int

    var body: some View {
        HStack(spacing: 0) {
            tabButton("Friends", index: 0, badge: nil)
            tabButton(
                "Requests",
                index: 1,
                badge: requestCount > 0 ? requestCount : nil
            )
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tabButton(
        _ title: String,
        index: Int,
        badge: Int?
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                if let badge {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(
                selectedTab == index ? .white : AppTheme.textMuted
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                selectedTab == index
                    ? AppTheme.cardSecondary
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(2)
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
    }
}

// MARK: - Incoming Request Row

private struct IncomingRequestRow: View {
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

private struct OutgoingRequestRow: View {
    let request: FriendRequestResponse

    var body: some View {
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

            Text("Pending")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textDim)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.card)
                .clipShape(Capsule())
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 24)
    }
}
