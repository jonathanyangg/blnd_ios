import Foundation

// MARK: - Requests

/// POST /notifications/device request body
struct RegisterDeviceRequest: Encodable {
    let token: String
    let platform: String
}

// swiftlint:disable discouraged_optional_boolean
/// PATCH /notifications/preferences request body (partial update)
struct UpdatePreferencesRequest: Encodable {
    let friendRequests: Bool?
    let groupInvites: Bool?
    let recommendations: Bool?
    let friendActivity: Bool?

    enum CodingKeys: String, CodingKey {
        case friendRequests = "friend_requests"
        case groupInvites = "group_invites"
        case recommendations
        case friendActivity = "friend_activity"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(friendRequests, forKey: .friendRequests)
        try container.encodeIfPresent(groupInvites, forKey: .groupInvites)
        try container.encodeIfPresent(recommendations, forKey: .recommendations)
        try container.encodeIfPresent(friendActivity, forKey: .friendActivity)
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

    var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: createdAt) else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        if seconds < 604_800 { return "\(seconds / 86400)d" }
        return "\(seconds / 604_800)w"
    }

    var icon: String {
        switch type {
        case "friend_request": return "person.badge.plus"
        case "friend_accepted": return "person.2.fill"
        case "group_invite": return "person.3.fill"
        case "group_watchlist": return "bookmark.fill"
        case "friend_activity": return "star.fill"
        case "weekly_digest": return "sparkles"
        default: return "bell.fill"
        }
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

/// GET/PATCH /notifications/preferences response
struct NotificationPreferences: Codable {
    let friendRequests: Bool
    let groupInvites: Bool
    let recommendations: Bool
    let friendActivity: Bool

    enum CodingKeys: String, CodingKey {
        case friendRequests = "friend_requests"
        case groupInvites = "group_invites"
        case recommendations
        case friendActivity = "friend_activity"
    }
}
