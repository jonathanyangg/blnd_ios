import Foundation

// MARK: - Requests

struct SendFriendRequestRequest: Encodable {
    let addresseeUsername: String

    enum CodingKeys: String, CodingKey {
        case addresseeUsername = "addressee_username"
    }
}

// MARK: - Responses

struct FriendResponse: Decodable, Identifiable {
    let friendshipId: Int?
    let id: String
    let username: String
    let displayName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case friendshipId = "friendship_id"
        case id, username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

struct FriendRequestResponse: Decodable, Identifiable {
    let id: Int
    let requester: FriendResponse
    let addressee: FriendResponse
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, requester, addressee, status
        case createdAt = "created_at"
    }
}

struct FriendListResponse: Decodable {
    let friends: [FriendResponse]
}

struct PendingRequestsResponse: Decodable {
    let incoming: [FriendRequestResponse]
    let outgoing: [FriendRequestResponse]
}

// MARK: - Contact Discovery

struct SuggestedFriendResponse: Decodable, Identifiable {
    let id: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let source: String
    let mutualCount: Int

    enum CodingKeys: String, CodingKey {
        case id, username, source
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case mutualCount = "mutual_count"
    }
}

struct FriendSuggestionsResponse: Decodable {
    let contacts: [SuggestedFriendResponse]
    let mutuals: [SuggestedFriendResponse]
}

struct UploadContactsRequest: Encodable {
    let phoneNumbers: [String]

    enum CodingKeys: String, CodingKey {
        case phoneNumbers = "phone_numbers"
    }
}
