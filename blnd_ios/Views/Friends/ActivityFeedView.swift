import SwiftUI
import UserNotifications

struct ActivityFeedView: View {
    @Environment(TabState.self) private var tabState
    private let isPreview: Bool

    @State private var frozen: ActivityFeedContent?
    @State private var items: [InboxItem] = []
    @State private var incoming: [FriendRequestResponse] = []
    @State private var useInboxFriendRequests = false
    @State private var hiddenFollowIds: Set<Int> = []
    @State private var isLoading: Bool
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var errorMessage: String?
    @State private var requestWarning: String?
    @State private var actionError: String?
    @State private var busyRequestId: String?
    @State private var route: ActivityRoute?

    private let pageSize = 30

    init(preview: ActivityFeedContent? = nil, forcedError: String? = nil) {
        let previewMode = preview != nil || forcedError != nil
        isPreview = previewMode
        _frozen = State(initialValue: preview)
        _errorMessage = State(initialValue: forcedError)
        _isLoading = State(initialValue: !previewMode)
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 60)
            } else if let errorMessage, items.isEmpty, frozen == nil {
                ErrorStateView(message: errorMessage) {
                    Task { await load(reset: true) }
                }
                .padding(.top, 40)
            } else if feed.requests.isEmpty, feed.sections.isEmpty {
                emptyState
            } else {
                feedList
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { BackButton() }
            ToolbarItem(placement: .principal) {
                Text("Notifications")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .navigationDestination(item: $route) { destination($0) }
        .task { await open() }
        .refreshable { await load(reset: true) }
        .accessibilityIdentifier("notifications-feed")
    }

    private var feed: ActivityFeedContent {
        if let frozen { return frozen }
        let visible = items.filter { item in
            guard item.type == "follow_request", let id = item.data?["follow_id"].flatMap(Int.init) else {
                return true
            }
            return !hiddenFollowIds.contains(id)
        }
        return ActivityFeed.make(
            inbox: visible,
            incoming: incoming,
            useInboxFriendRequests: useInboxFriendRequests,
            filter: NotificationPrefsStore.load().inApp,
            now: Date()
        )
    }

    private var feedList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if let actionError { banner(actionError) }
            if let requestWarning { banner(requestWarning) }
            if !feed.requests.isEmpty {
                sectionHeader("Requests")
                ForEach(feed.requests) { request in
                    ActivityRequestRow(
                        request: request,
                        isBusy: busyRequestId == request.id,
                        onAccept: { await decide(request, accept: true) },
                        onDecline: { await decide(request, accept: false) },
                        onOpen: { route = request.profile }
                    )
                }
            }
            ForEach(feed.sections, id: \.bucket) { section in
                sectionHeader(section.bucket.rawValue)
                ForEach(section.rows) { row in
                    activityButton(row)
                        .onAppear {
                            guard row.id == feed.sections.last?.rows.last?.id else { return }
                            Task { await loadMore() }
                        }
                }
            }
            if isLoadingMore {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.textDim)
            Text("No notifications yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("Activity from friends and blends will show up here")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 4)
    }

    private func banner(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppTheme.cardSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }

    @ViewBuilder
    private func activityButton(_ row: ActivityRow) -> some View {
        if let destination = row.route {
            Button { route = destination } label: { ActivityRowView(row: row) }
                .buttonStyle(.plain)
        } else {
            ActivityRowView(row: row)
        }
    }

    @ViewBuilder
    private func destination(_ route: ActivityRoute) -> some View {
        switch route {
        case let .movie(tmdbId, title):
            MovieDetailView(tmdbId: tmdbId, title: title, source: .notification)
        case let .comments(tmdbId, title):
            MovieCommentsView(tmdbId: tmdbId, movieTitle: title.isEmpty ? "Comments" : title)
        case let .group(id):
            GroupDetailView(groupId: id)
        case let .profile(userId, username, avatarURL):
            FriendProfileView(
                friend: FriendResponse(
                    friendshipId: nil,
                    id: userId,
                    username: username,
                    displayName: nil,
                    avatarUrl: avatarURL
                )
            )
        }
    }

    private func open() async {
        guard !isPreview else { return }
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
        let loaded = await load(reset: true)
        guard loaded else { return }
        try? await NotificationAPI.markInboxRead()
        try? await NotificationAPI.resetBadge()
    }

    @discardableResult
    private func load(reset: Bool) async -> Bool {
        if isPreview { return false }
        if reset {
            errorMessage = nil
            hasMore = true
        }
        do {
            async let inboxTask = NotificationAPI.getInbox(limit: pageSize, offset: 0)
            async let requestsTask = loadRequests()
            let inbox = try await inboxTask
            let requests = await requestsTask
            guard !Task.isCancelled else { return false }
            items = inbox.results
            incoming = requests.incoming
            useInboxFriendRequests = requests.failed
            requestWarning = requests.failed ? "Couldn't load friend requests." : nil
            hasMore = inbox.results.count >= pageSize
            isLoading = false
            return true
        } catch {
            guard !Task.isCancelled else { return false }
            if items.isEmpty { errorMessage = FriendlyCopy.notificationsMessage(for: error) }
            isLoading = false
            return false
        }
    }

    private func loadRequests() async -> (incoming: [FriendRequestResponse], failed: Bool) {
        do {
            let response = try await FriendsAPI.getPendingRequests()
            return (response.incoming, false)
        } catch {
            return ([], true)
        }
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading, !isPreview else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await NotificationAPI.getInbox(limit: pageSize, offset: items.count)
            let existing = Set(items.map(\.id))
            items.append(contentsOf: response.results.filter { !existing.contains($0.id) })
            hasMore = response.results.count >= pageSize
        } catch {
            hasMore = false
        }
    }

    private func decide(_ request: PinnedRequest, accept: Bool) async {
        actionError = nil
        if isPreview {
            guard var preview = frozen else { return }
            preview.requests.removeAll { $0.id == request.id }
            frozen = preview
            return
        }
        busyRequestId = request.id
        defer { busyRequestId = nil }
        do {
            try await perform(request, accept: accept)
            remove(request)
            await tabState.refreshPendingCount()
        } catch {
            actionError = FriendlyCopy.requestAction
        }
    }

    private func perform(_ request: PinnedRequest, accept: Bool) async throws {
        switch request.kind {
        case .friend:
            guard let id = request.friendshipId else { throw FriendlyFailure() }
            if accept {
                _ = try await FriendsService.acceptRequest(friendshipId: id)
                Analytics.friendRequestAccepted()
            } else {
                _ = try await FriendsService.rejectRequest(friendshipId: id)
                Analytics.friendRequestRejected()
            }
        case .follow:
            guard let id = request.followId else { throw FriendlyFailure() }
            if accept {
                try await FriendsService.acceptFollow(followId: id)
            } else {
                try await FriendsService.declineFollow(followId: id)
            }
        }
    }

    private func remove(_ request: PinnedRequest) {
        if let friendshipId = request.friendshipId {
            incoming.removeAll { $0.id == friendshipId }
        }
        if let followId = request.followId {
            hiddenFollowIds.insert(followId)
        }
        items.removeAll { $0.type == request.kind.inboxType && $0.fromUsername == request.name }
    }
}

private struct FriendlyFailure: Error {}

private extension PinnedRequest.Kind {
    var inboxType: String {
        switch self {
        case .friend: "friend_request"
        case .follow: "follow_request"
        }
    }
}
