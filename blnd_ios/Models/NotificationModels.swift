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
