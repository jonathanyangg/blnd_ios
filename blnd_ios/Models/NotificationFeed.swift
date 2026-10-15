import Foundation

// shortcut: inbox items are one actor each, upgrade when the API returns aggregated rows
enum ActivityBucket: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This week"
    case earlier = "Earlier"
}

enum ActivityKind: Equatable {
    case blendInvite
    case blendActivity
    case like
    case comment
    case watchedWith
    case match
    case recommendation
    case rating
    case friendAccepted
    case other
}

struct ActivityActor: Equatable {
    let name: String
    let avatarURL: String?
}

enum ActivityRoute: Hashable {
    case movie(tmdbId: Int, title: String)
    case comments(tmdbId: Int, title: String)
    case group(Int)
    case profile(userId: String, username: String, avatarURL: String?)
}

struct ActivityRow: Identifiable, Equatable {
    let id: String
    let actors: [ActivityActor]
    let lineLead: String
    let lineRest: String
    let time: String
    let isUnread: Bool
    let posterURL: URL?
    let route: ActivityRoute?
}

struct PinnedRequest: Identifiable, Equatable {
    enum Kind: Equatable {
        case friend
        case follow
    }

    let id: String
    let kind: Kind
    let name: String
    let avatarURL: String?
    let date: Date
    let isUnread: Bool
    let friendshipId: Int?
    let followId: Int?
    let profile: ActivityRoute
}

struct ActivitySection: Equatable {
    let bucket: ActivityBucket
    let rows: [ActivityRow]
}

struct ActivityFeedContent: Equatable {
    var requests: [PinnedRequest]
    var sections: [ActivitySection]
}

enum ActivityFeed {
    static func make(
        inbox: [InboxItem],
        incoming: [FriendRequestResponse],
        useInboxFriendRequests: Bool,
        filter: ChannelPrefs,
        now: Date
    ) -> ActivityFeedContent {
        ActivityFeedContent(
            requests: pinnedRequests(
                inbox: inbox,
                incoming: incoming,
                useInboxFriendRequests: useInboxFriendRequests
            ),
            sections: activitySections(inbox: inbox, filter: filter, now: now)
        )
    }

    static func deepLink(type: String, data: [String: String]) -> DeepLink? {
        switch kind(for: type) {
        case nil:
            return type == "friend_request" || type == "follow_request" ? .friendRequests : nil
        case .blendInvite, .blendActivity:
            return data["group_id"].flatMap(Int.init).map(DeepLink.groupDetail(groupId:))
        case .like, .comment:
            return data["tmdb_id"].flatMap(Int.init).map(DeepLink.comments(tmdbId:))
        case .friendAccepted:
            return .friendRequests
        case .watchedWith, .match, .recommendation, .rating, .other:
            return data["tmdb_id"].flatMap(Int.init).map(DeepLink.movieDetail(tmdbId:))
        }
    }

    static func actorPhrase(_ names: [String]) -> String {
        switch names.count {
        case 0: return "Someone"
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return "\(names[0]) and \(names.count - 1) others"
        }
    }

    static func bucket(for date: Date, now: Date, calendar: Calendar = .current) -> ActivityBucket {
        if date >= calendar.startOfDay(for: now) { return .today }
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        return date >= weekStart ? .thisWeek : .earlier
    }

    private static let kinds: [String: ActivityKind] = [
        "group_invite": .blendInvite,
        "blend_invite": .blendInvite,
        "group_watchlist": .blendActivity,
        "blend_activity": .blendActivity,
        "like": .like,
        "comment_like": .like,
        "comment_reply": .comment,
        "comment_replies": .comment,
        "comment_mention": .comment,
        "comment_mentions": .comment,
        "comment": .comment,
        "watched_with": .watchedWith,
        "match": .match,
        "new_match": .match,
        "recommendation": .recommendation,
        "recommendations": .recommendation,
        "weekly_digest": .recommendation,
        "friend_activity": .rating,
        "friend_accepted": .friendAccepted,
    ]

    static func kind(for type: String) -> ActivityKind? {
        if type == "friend_request" || type == "follow_request" { return nil }
        return kinds[type] ?? .other
    }

    static func parseDate(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}

extension ChannelPrefs {
    func allows(_ kind: ActivityKind) -> Bool {
        switch kind {
        case .rating: friendRatings
        case .blendInvite, .blendActivity: blendActivity
        case .like, .comment: commentsLikes
        case .watchedWith: watchedWith
        case .recommendation: recommendations
        case .match, .friendAccepted, .other: true
        }
    }
}

enum FriendlyCopy {
    static let requestAction = "Couldn't update that request. Please try again."
    static let saveSettings = "Couldn't save that setting. Please try again."
    static let refreshSettings =
        "Couldn't refresh your notification settings. Showing what was saved on this phone."

    static func notificationsMessage(for error: Error) -> String {
        isOffline(error) ? "No internet connection" : "Couldn't load your notifications."
    }

    private static func isOffline(_ error: Error) -> Bool {
        switch error {
        case APIError.networkError, APIError.refreshUnavailable:
            true
        default:
            false
        }
    }
}

// MARK: - Grouping

private extension ActivityFeed {
    static func pinnedRequests(
        inbox: [InboxItem],
        incoming: [FriendRequestResponse],
        useInboxFriendRequests: Bool
    ) -> [PinnedRequest] {
        var rows = incoming.map(friendRequest)
        for item in inbox {
            if item.type == "follow_request" {
                rows.append(followRequest(item))
            } else if useInboxFriendRequests, item.type == "friend_request" {
                rows.append(inboxFriendRequest(item))
            }
        }
        return rows.sorted { $0.date > $1.date }
    }

    static func friendRequest(_ request: FriendRequestResponse) -> PinnedRequest {
        let person = request.requester
        let name = person.displayName ?? person.username
        return PinnedRequest(
            id: "friend-\(request.id)",
            kind: .friend,
            name: name,
            avatarURL: person.avatarUrl,
            date: parseDate(request.createdAt) ?? .distantPast,
            isUnread: true,
            friendshipId: request.id,
            followId: nil,
            profile: .profile(userId: person.id, username: person.username, avatarURL: person.avatarUrl)
        )
    }

    static func followRequest(_ item: InboxItem) -> PinnedRequest {
        requestRow(item, kind: .follow, idPrefix: "follow", followId: int(item.data, "follow_id"), friendshipId: nil)
    }

    static func inboxFriendRequest(_ item: InboxItem) -> PinnedRequest {
        requestRow(
            item,
            kind: .friend,
            idPrefix: "friend-inbox",
            followId: nil,
            friendshipId: int(item.data, "friendship_id")
        )
    }

    static func requestRow(
        _ item: InboxItem,
        kind: PinnedRequest.Kind,
        idPrefix: String,
        followId: Int?,
        friendshipId: Int?
    ) -> PinnedRequest {
        let name = item.fromUsername ?? "Someone"
        let userId = item.data?["user_id"] ?? ""
        return PinnedRequest(
            id: "\(idPrefix)-\(item.id)",
            kind: kind,
            name: name,
            avatarURL: item.fromAvatarUrl,
            date: parseDate(item.createdAt) ?? .distantPast,
            isUnread: !item.read,
            friendshipId: friendshipId,
            followId: followId,
            profile: .profile(userId: userId, username: name, avatarURL: item.fromAvatarUrl)
        )
    }

    static func activitySections(
        inbox: [InboxItem],
        filter: ChannelPrefs,
        now: Date
    ) -> [ActivitySection] {
        let sorted = inbox.sorted {
            (parseDate($0.createdAt) ?? .distantPast) > (parseDate($1.createdAt) ?? .distantPast)
        }
        var grouped: [ActivityBucket: [String: Accumulator]] = [:]
        var order: [ActivityBucket: [String]] = [:]
        for item in sorted {
            guard let kind = kind(for: item.type), filter.allows(kind), let date = parseDate(item.createdAt) else {
                continue
            }
            let bucket = bucket(for: date, now: now)
            let key = groupKey(kind: kind, item: item)
            if grouped[bucket]?[key] == nil {
                order[bucket, default: []].append(key)
            }
            var accumulator = grouped[bucket]?[key] ?? Accumulator(kind: kind, date: date, item: item)
            accumulator.add(item: item, date: date)
            grouped[bucket, default: [:]][key] = accumulator
        }
        return ActivityBucket.allCases.compactMap { bucket in
            let rows = (order[bucket] ?? []).compactMap { grouped[bucket]?[$0]?.row(id: "\(bucket.rawValue)-\($0)") }
            return rows.isEmpty ? nil : ActivitySection(bucket: bucket, rows: rows)
        }
    }

    static func groupKey(kind: ActivityKind, item: InboxItem) -> String {
        let data = item.data ?? [:]
        if let comment = data["comment_id"], kind == .like || kind == .comment {
            return "\(kind)-comment-\(comment)"
        }
        if let tmdb = data["tmdb_id"], !tmdb.isEmpty, kind != .blendInvite {
            return "\(kind)-tmdb-\(tmdb)"
        }
        if let group = data["group_id"], !group.isEmpty {
            return "\(kind)-group-\(group)"
        }
        if let user = data["user_id"], !user.isEmpty {
            return "\(kind)-user-\(user)"
        }
        return "\(kind)-item-\(item.id)"
    }

    static func int(_ data: [String: String]?, _ key: String) -> Int? {
        data?[key].flatMap(Int.init)
    }
}

private struct Accumulator {
    let kind: ActivityKind
    var actors: [ActivityActor] = []
    var isUnread = false
    var date: Date
    var item: InboxItem
    var posterURL: URL?

    init(kind: ActivityKind, date: Date, item: InboxItem) {
        self.kind = kind
        self.date = date
        self.item = item
    }

    mutating func add(item: InboxItem, date: Date) {
        if date >= self.date {
            self.date = date
            self.item = item
        }
        if posterURL == nil { posterURL = ActivityFeed.posterURL(item.data) }
        isUnread = isUnread || !item.read
        let name = item.fromUsername ?? "Someone"
        if !actors.contains(where: { $0.name == name }) {
            actors.append(ActivityActor(name: name, avatarURL: item.fromAvatarUrl))
        }
    }

    func row(id: String) -> ActivityRow {
        let names = actors.map(\.name)
        let aggregated = names.count > 1
        let lead = aggregated ? ActivityFeed.actorPhrase(names) : singleLead(names.first ?? "")
        let rest = aggregated
            ? " \(ActivityFeed.action(kind: kind, data: item.data))"
            : singleRest(lead: lead)
        return ActivityRow(
            id: id,
            actors: actors,
            lineLead: lead,
            lineRest: rest,
            time: ActivityFeed.timeAgo(since: date),
            isUnread: isUnread,
            posterURL: posterURL,
            route: ActivityFeed.route(kind: kind, item: item)
        )
    }

    private func singleLead(_ name: String) -> String {
        item.body.hasPrefix(name) ? name : ""
    }

    private func singleRest(lead: String) -> String {
        if !lead.isEmpty { return String(item.body.dropFirst(lead.count)) }
        if item.body.isEmpty { return " \(ActivityFeed.action(kind: kind, data: item.data))" }
        return item.body
    }
}

extension ActivityFeed {
    static func posterURL(_ data: [String: String]?) -> URL? {
        if let raw = data?["poster_url"], let url = URL(string: raw), url.scheme != nil { return url }
        guard let path = data?["poster_path"], !path.isEmpty else { return nil }
        let suffix = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: "https://image.tmdb.org/t/p/w185\(suffix)")
    }

    static func action(kind: ActivityKind, data: [String: String]?) -> String {
        let movie = data?["movie_title"].flatMap { $0.isEmpty ? nil : $0 }
        let group = data?["group_name"].flatMap { $0.isEmpty ? nil : $0 }
        switch kind {
        case .blendInvite:
            return group.map { "added you to \($0)" } ?? "added you to a Blend"
        case .blendActivity:
            return movie.map { "added \($0) to a Blend" } ?? "added a title to a Blend"
        case .like:
            return movie.map { "liked your comment on \($0)" } ?? "liked your comment"
        case .comment:
            return movie.map { "commented on \($0)" } ?? "commented on a movie"
        case .watchedWith:
            return movie.map { "watched \($0) with you" } ?? "tagged you as watched with"
        case .match:
            return movie.map { "matched with you on \($0)" } ?? "is a new match"
        case .recommendation:
            return movie.map { "recommended \($0)" } ?? "sent you a recommendation"
        case .rating:
            return movie.map { "rated \($0)" } ?? "rated a movie"
        case .friendAccepted:
            return "accepted your friend request"
        case .other:
            return "sent you an update"
        }
    }

    static func route(kind: ActivityKind, item: InboxItem) -> ActivityRoute? {
        let data = item.data ?? [:]
        let title = data["movie_title"] ?? ""
        switch kind {
        case .blendInvite, .blendActivity:
            if let id = data["group_id"].flatMap(Int.init) { return .group(id) }
            if let id = data["tmdb_id"].flatMap(Int.init) { return .movie(tmdbId: id, title: title) }
        case .like, .comment:
            if let id = data["tmdb_id"].flatMap(Int.init) { return .comments(tmdbId: id, title: title) }
        case .friendAccepted:
            if let userId = data["user_id"] {
                return .profile(userId: userId, username: item.fromUsername ?? "", avatarURL: item.fromAvatarUrl)
            }
        case .watchedWith, .match, .recommendation, .rating, .other:
            if let id = data["tmdb_id"].flatMap(Int.init) { return .movie(tmdbId: id, title: title) }
            if let id = data["group_id"].flatMap(Int.init) { return .group(id) }
        }
        return nil
    }

    static func timeAgo(since date: Date, now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3_600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3_600)h" }
        if seconds < 604_800 { return "\(seconds / 86_400)d" }
        return "\(seconds / 604_800)w"
    }
}
