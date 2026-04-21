import Foundation

/// Friends endpoints: list, request, accept, reject, remove
enum FriendsAPI {
    /// GET /friends/ — list accepted friends
    static func listFriends() async throws -> FriendListResponse {
        try await APIClient.shared.request(
            endpoint: "/friends/",
            authenticated: true
        )
    }

    /// GET /friends/requests — get pending incoming + outgoing requests
    static func getPendingRequests() async throws -> PendingRequestsResponse {
        try await APIClient.shared.request(
            endpoint: "/friends/requests",
            authenticated: true
        )
    }

    /// DELETE /friends/blocks/{userId} — unblock a user
    static func unblockUser(userId: String) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/friends/blocks/\(userId)",
            method: "DELETE",
            authenticated: true
        )
    }

    /// GET /friends/blocks — list all blocked users
    static func listBlockedUsers() async throws -> BlockedUsersResponse {
        try await APIClient.shared.request(
            endpoint: "/friends/blocks",
            authenticated: true
        )
    }

    /// POST /friends/contacts — upload phone numbers for contact matching
    static func uploadContacts(phoneNumbers: [String]) async throws {
        let body = UploadContactsRequest(phoneNumbers: phoneNumbers)
        try await APIClient.shared.requestVoid(
            endpoint: "/friends/contacts",
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    /// GET /friends/suggestions — contact matches + mutual friends
    static func getSuggestions() async throws -> FriendSuggestionsResponse {
        try await APIClient.shared.request(
            endpoint: "/friends/suggestions",
            authenticated: true
        )
    }

    /// GET /friends/{userId}/mutuals — mutual friends with a specific user
    static func getMutuals(userId: String) async throws -> MutualFriendsResponse {
        try await APIClient.shared.request(
            endpoint: "/friends/\(userId)/mutuals",
            authenticated: true
        )
    }

    /// POST /reports — flag a user for objectionable content / abusive behavior.
    /// Backend is expected to action reports within 24 hours per App Store guidelines.
    static func reportUser(userId: String, reason: String) async throws {
        let body = ReportUserRequest(reportedUserId: userId, reason: reason)
        try await APIClient.shared.requestVoid(
            endpoint: "/reports",
            method: "POST",
            body: body,
            authenticated: true
        )
    }
}

struct ReportUserRequest: Encodable {
    let reportedUserId: String
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reportedUserId = "reported_user_id"
        case reason
    }
}
