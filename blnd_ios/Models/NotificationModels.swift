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
    var shareRatings: ShareAudience = .friends
    var inApp = ChannelPrefs()
    var push = ChannelPrefs()

    func applying(server: NotificationPreferences) -> NotificationPrivacyPrefs {
        var merged = self
        if let audience = ShareAudience.parse(server.shareRatings) {
            merged.shareRatings = audience
        }
        if let inApp = server.inApp { merged.inApp = inApp }
        if let push = server.push {
            merged.push = push
        } else {
            merged.push.friendRatings = server.friendActivity
            merged.push.blendActivity = server.groupInvites
            merged.push.commentsLikes = server.commentReplies
            merged.push.recommendations = server.recommendations
        }
        return merged
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

// shortcut: prefs API stores five push booleans, upgrade when it stores share_ratings and both channels
enum NotificationPrefsStore {
    private static let key = "blnd.notificationPrivacy"

    static func load() -> NotificationPrivacyPrefs {
        guard let data = UserDefaults.standard.data(forKey: key),
              let prefs = try? JSONDecoder().decode(NotificationPrivacyPrefs.self, from: data) else {
            return NotificationPrivacyPrefs()
        }
        return prefs
    }

    static func save(_ prefs: NotificationPrivacyPrefs) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        UserDefaults.standard.set(data, forKey: key)
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
        try encode(to: encoder, includeExtensions: true)
    }

    func encode(to encoder: Encoder, includeExtensions: Bool) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(friendRequests, forKey: .friendRequests)
        try container.encodeIfPresent(groupInvites, forKey: .groupInvites)
        try container.encodeIfPresent(recommendations, forKey: .recommendations)
        try container.encodeIfPresent(friendActivity, forKey: .friendActivity)
        try container.encodeIfPresent(commentReplies, forKey: .commentReplies)
        guard includeExtensions else { return }
        try container.encodeIfPresent(shareRatings, forKey: .shareRatings)
        try container.encodeIfPresent(inApp, forKey: .inApp)
        try container.encodeIfPresent(push, forKey: .push)
    }
}

// swiftlint:enable discouraged_optional_boolean

// MARK: - Responses

/// GET /notifications/inbox item
struct InboxItem: Decodable, Identifiable {
    let id: Int
    let type: String
    let fromUsername: String?
    let fromAvatarUrl: String?
    let title: String
    let body: String
    let data: [String: String]?
    let read: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, data, read
        case fromUsername = "from_username"
        case fromAvatarUrl = "from_avatar_url"
        case createdAt = "created_at"
    }
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

    init(
        friendRequests: Bool,
        groupInvites: Bool,
        recommendations: Bool,
        friendActivity: Bool,
        commentReplies: Bool,
        shareRatings: String? = nil,
        inApp: ChannelPrefs? = nil,
        push: ChannelPrefs? = nil
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
        shareRatings = try? container.decode(String.self, forKey: .shareRatings)
        inApp = try? container.decode(ChannelPrefs.self, forKey: .inApp)
        push = try? container.decode(ChannelPrefs.self, forKey: .push)
    }
}
