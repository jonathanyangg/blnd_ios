import Foundation

// MARK: - Requests

/// POST /notifications/device request body
struct RegisterDeviceRequest: Encodable {
    let token: String
    let platform: String
}

enum ShareAudience: String, CaseIterable, Codable {
    case everyone
    case friends
    case off

    var label: String {
        switch self {
        case .everyone: "Everyone"
        case .friends: "Friends"
        case .off: "Off"
        }
    }

    static func parse(_ raw: String?) -> ShareAudience? {
        guard let raw else { return nil }
        return ShareAudience(rawValue: raw.lowercased())
    }
}

struct ChannelPrefs: Codable, Equatable {
    var friendRatings = true
    var blendActivity = true
    var commentsLikes = true
    var watchedWith = true
    var recommendations = true

    enum CodingKeys: String, CodingKey {
        case friendRatings = "friend_ratings"
        case blendActivity = "blend_activity"
        case commentsLikes = "comments_likes"
        case watchedWith = "watched_with"
        case recommendations
    }
}

struct NotificationPrivacyPrefs: Codable, Equatable {
    var shareRatings: ShareAudience
    var inApp: ChannelPrefs
    var push: ChannelPrefs

    init(
        shareRatings: ShareAudience = .friends,
        inApp: ChannelPrefs = ChannelPrefs(),
        push: ChannelPrefs = ChannelPrefs()
    ) {
        self.shareRatings = shareRatings
        self.inApp = inApp
        self.push = push
    }

    init(server: NotificationPreferences) {
        shareRatings = ShareAudience.parse(server.shareRatings) ?? .friends
        inApp = server.inApp
        push = server.push
    }

    func asRequest() -> UpdatePreferencesRequest {
        UpdatePreferencesRequest(
            friendRequests: nil,
            groupInvites: push.blendActivity,
            recommendations: push.recommendations,
            friendActivity: push.friendRatings,
            commentReplies: push.commentsLikes,
            shareRatings: shareRatings.rawValue,
            inApp: inApp,
            push: push
        )
    }
}

// swiftlint:disable discouraged_optional_boolean
/// PATCH /notifications/preferences request body (partial update)
struct UpdatePreferencesRequest: Encodable {
    let friendRequests: Bool?
    let groupInvites: Bool?
    let recommendations: Bool?
    let friendActivity: Bool?
    let commentReplies: Bool?
    let shareRatings: String?
    let inApp: ChannelPrefs?
    let push: ChannelPrefs?

    enum CodingKeys: String, CodingKey {
        case friendRequests = "friend_requests"
        case groupInvites = "group_invites"
        case recommendations
        case friendActivity = "friend_activity"
        case commentReplies = "comment_replies"
        case shareRatings = "share_ratings"
        case inApp = "in_app"
        case push
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(friendRequests, forKey: .friendRequests)
        try container.encodeIfPresent(groupInvites, forKey: .groupInvites)
        try container.encodeIfPresent(recommendations, forKey: .recommendations)
        try container.encodeIfPresent(friendActivity, forKey: .friendActivity)
        try container.encodeIfPresent(commentReplies, forKey: .commentReplies)
        try container.encodeIfPresent(shareRatings, forKey: .shareRatings)
        try container.encodeIfPresent(inApp, forKey: .inApp)
        try container.encodeIfPresent(push, forKey: .push)
    }
}

// swiftlint:enable discouraged_optional_boolean

// MARK: - Responses

struct InboxTarget: Decodable, Equatable {
    let type: String
    let id: String
}

/// One actor. The client combines rows that share `group_key`.
struct InboxItem: Decodable, Identifiable, Equatable {
    let id: Int
    let type: String
    let fromUsername: String?
    let fromAvatarUrl: String?
    let avatarUrl: String?
    let posterUrl: String?
    let groupKey: String?
    let target: InboxTarget?
    let title: String
    let body: String
    let data: [String: String]?
    let read: Bool
    let createdAt: String
    let actions: [String]

    var displayAvatar: String? { avatarUrl ?? fromAvatarUrl }

    var canRespond: Bool { actions.contains("accept") && actions.contains("decline") }

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, data, read, target, actions
        case fromUsername = "from_username"
        case fromAvatarUrl = "from_avatar_url"
        case avatarUrl = "avatar_url"
        case posterUrl = "poster_url"
        case groupKey = "group_key"
        case createdAt = "created_at"
    }

    init(
        id: Int,
        type: String,
        fromUsername: String?,
        fromAvatarUrl: String?,
        avatarUrl: String? = nil,
        posterUrl: String? = nil,
        groupKey: String? = nil,
        target: InboxTarget? = nil,
        title: String,
        body: String,
        data: [String: String]?,
        read: Bool,
        createdAt: String,
        actions: [String] = []
    ) {
        self.id = id
        self.type = type
        self.fromUsername = fromUsername
        self.fromAvatarUrl = fromAvatarUrl
        self.avatarUrl = avatarUrl
        self.posterUrl = posterUrl
        self.groupKey = groupKey
        self.target = target
        self.title = title
        self.body = body
        self.data = data
        self.read = read
        self.createdAt = createdAt
        self.actions = actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        fromUsername = try container.decodeIfPresent(String.self, forKey: .fromUsername)
        fromAvatarUrl = try container.decodeIfPresent(String.self, forKey: .fromAvatarUrl)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        posterUrl = try container.decodeIfPresent(String.self, forKey: .posterUrl)
        groupKey = try container.decodeIfPresent(String.self, forKey: .groupKey)
        target = try container.decodeIfPresent(InboxTarget.self, forKey: .target)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        data = try container.decodeIfPresent(LooseStringMap.self, forKey: .data)?.values
        read = try container.decode(Bool.self, forKey: .read)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        actions = try container.decodeIfPresent([String].self, forKey: .actions) ?? []
    }
}

/// Inbox `data` is a JSON object. Keep string fields and ignore the rest.
private struct LooseStringMap: Decodable {
    let values: [String: String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var values: [String: String] = [:]
        for key in container.allKeys {
            if let value = try? container.decode(String.self, forKey: key) {
                values[key.stringValue] = value
            }
        }
        self.values = values
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

/// GET /notifications/inbox response
struct InboxResponse: Decodable {
    let results: [InboxItem]
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case results
        case unreadCount = "unread_count"
    }
}

/// GET/PATCH /notifications/preferences response.
/// Extra keys are optional until the server stores channels and sharing.
struct NotificationPreferences: Decodable, Equatable {
    let friendRequests: Bool
    let groupInvites: Bool
    let recommendations: Bool
    let friendActivity: Bool
    let commentReplies: Bool
    let shareRatings: String
    let inApp: ChannelPrefs
    let push: ChannelPrefs

    enum CodingKeys: String, CodingKey {
        case friendRequests = "friend_requests"
        case groupInvites = "group_invites"
        case recommendations
        case friendActivity = "friend_activity"
        case commentReplies = "comment_replies"
        case shareRatings = "share_ratings"
        case inApp = "in_app"
        case push
    }

    init(
        friendRequests: Bool,
        groupInvites: Bool,
        recommendations: Bool,
        friendActivity: Bool,
        commentReplies: Bool,
        shareRatings: String,
        inApp: ChannelPrefs,
        push: ChannelPrefs
    ) {
        self.friendRequests = friendRequests
        self.groupInvites = groupInvites
        self.recommendations = recommendations
        self.friendActivity = friendActivity
        self.commentReplies = commentReplies
        self.shareRatings = shareRatings
        self.inApp = inApp
        self.push = push
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        friendRequests = try container.decode(Bool.self, forKey: .friendRequests)
        groupInvites = try container.decode(Bool.self, forKey: .groupInvites)
        recommendations = try container.decode(Bool.self, forKey: .recommendations)
        friendActivity = try container.decode(Bool.self, forKey: .friendActivity)
        commentReplies = try container.decode(Bool.self, forKey: .commentReplies)
        shareRatings = try container.decode(String.self, forKey: .shareRatings)
        inApp = try container.decode(ChannelPrefs.self, forKey: .inApp)
        push = try container.decode(ChannelPrefs.self, forKey: .push)
    }
}
