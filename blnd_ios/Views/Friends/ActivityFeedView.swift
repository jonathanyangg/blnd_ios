import SwiftUI
import UserNotifications

struct ActivityFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DeepLinkState.self) private var deepLinkState
    @Environment(TabState.self) private var tabState
    @State private var requests: PendingRequestsResponse?
    @State private var items: [InboxItem] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var errorMessage: UserFacingError?

    private let pageSize = 30

    var body: some View {
        ScrollView {
            requestSections
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 60)
            } else if let error = errorMessage {
                ErrorStateView(message: error) {
                    Task { await loadInbox(reset: true) }
                }
                .padding(.top, 60)
            } else if items.isEmpty, (requests?.incoming ?? []).isEmpty, (requests?.outgoing ?? []).isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.textDim)
                    Text("No notifications yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Friend requests and activity from blends show up here")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button { handleTap(item) } label: {
                            inboxRow(item)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if index >= items.count - 5 {
                                Task { await loadMore() }
                            }
                        }

                        Divider()
                            .background(AppTheme.cardSecondary)
                            .padding(.horizontal, 24)
                    }

                    if isLoadingMore {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                }
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .principal) {
                Text("Notifications")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
            await loadRequests()
            await loadInbox(reset: true)
            // Mark all as read when viewing
            try? await NotificationAPI.markInboxRead()
            try? await NotificationAPI.resetBadge()
        }
        .refreshable {
            await loadRequests()
            await loadInbox(reset: true)
        }
    }

    // MARK: - Inbox Row

    private func inboxRow(_ item: InboxItem) -> some View {
        HStack(spacing: 12) {
            // Avatar or icon
            if let avatarUrl = item.fromAvatarUrl {
                AvatarView(url: avatarUrl, size: 40)
            } else {
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.cardSecondary)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.body)
                    .font(.system(size: 14))
                    .foregroundStyle(item.read ? AppTheme.textMuted : .white)
                    .lineLimit(2)

                Text(item.timeAgo)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textDim)
            }

            Spacer()

            if !item.read {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Data

    @ViewBuilder
    private var requestSections: some View {
        let incoming = requests?.incoming ?? []
        let outgoing = requests?.outgoing ?? []
        if !incoming.isEmpty {
            requestHeader("Requests")
            ForEach(incoming) { request in
                IncomingRequestRow(request: request) {
                    await respond(request, accept: true)
                } onReject: {
                    await respond(request, accept: false)
                }
                Divider().background(AppTheme.cardSecondary).padding(.horizontal, 24)
            }
        }
        if !outgoing.isEmpty {
            requestHeader("Sent")
            ForEach(outgoing) { request in
                OutgoingRequestRow(
                    request: request,
                    destination: FriendProfileView(friend: FriendResponse(
                        friendshipId: nil,
                        id: request.addressee.id,
                        username: request.addressee.username,
                        displayName: request.addressee.displayName,
                        avatarUrl: request.addressee.avatarUrl
                    ))
                ) {
                    await withdraw(request)
                }
                Divider().background(AppTheme.cardSecondary).padding(.horizontal, 24)
            }
        }
    }

    private func requestHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func loadRequests() async {
        requests = try? await FriendsAPI.getPendingRequests()
        await tabState.refreshPendingCount()
    }

    private func respond(_ request: FriendRequestResponse, accept: Bool) async {
        do {
            if accept {
                _ = try await FriendsService.acceptRequest(friendshipId: request.id)
                Analytics.friendRequestAccepted()
            } else {
                _ = try await FriendsService.rejectRequest(friendshipId: request.id)
                Analytics.friendRequestRejected()
            }
            UserActionCache.shared.invalidateFriends()
            await loadRequests()
        } catch {
            return
        }
    }

    private func withdraw(_ request: FriendRequestResponse) async {
        do {
            try await FriendsService.withdrawRequest(friendshipId: request.id)
            await loadRequests()
        } catch {
            return
        }
    }

    private func loadInbox(reset: Bool) async {
        if reset {
            errorMessage = nil
            hasMore = true
        }
        do {
            let response = try await NotificationAPI.getInbox(limit: pageSize, offset: 0)
            items = response.results
            hasMore = response.results.count >= pageSize
        } catch {
            if items.isEmpty {
                errorMessage = UserFacingError.capture(error, screen: "Activity")
            }
        }
        isLoading = false
    }

    private func handleTap(_ item: InboxItem) {
        let route: DeepLink? = switch item.type {
        case "group_invite", "group_watchlist":
            (item.data?["group_id"]).flatMap(Int.init).map(DeepLink.groupDetail(groupId:))
        case "friend_activity", "friend_accepted":
            (item.data?["tmdb_id"]).flatMap(Int.init).map(DeepLink.movieDetail(tmdbId:))
        default:
            nil
        }
        guard let route else { return }
        deepLinkState.pending = route
        dismiss()
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await NotificationAPI.getInbox(
                limit: pageSize,
                offset: items.count
            )
            let existingIds = Set(items.map(\.id))
            let new = response.results.filter { !existingIds.contains($0.id) }
            items.append(contentsOf: new)
            hasMore = response.results.count >= pageSize
        } catch {
            // Non-critical — stop paging on error
            hasMore = false
        }
    }
}
