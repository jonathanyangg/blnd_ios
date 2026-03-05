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

    /// POST /friends/request — send a friend request by username
    static func sendRequest(username: String) async throws -> FriendRequestResponse {
        let body = SendFriendRequestRequest(addresseeUsername: username)
        return try await APIClient.shared.request(
            endpoint: "/friends/request",
            method: "POST",
            body: body,
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

    /// POST /friends/{id}/accept — accept a friend request
    static func acceptRequest(friendshipId: Int) async throws -> FriendRequestResponse {
        try await APIClient.shared.request(
            endpoint: "/friends/\(friendshipId)/accept",
            method: "POST",
            authenticated: true
        )
    }

    /// POST /friends/{id}/reject — reject a friend request
    static func rejectRequest(friendshipId: Int) async throws -> FriendRequestResponse {
        try await APIClient.shared.request(
            endpoint: "/friends/\(friendshipId)/reject",
            method: "POST",
            authenticated: true
        )
    }

    /// DELETE /friends/{id} — remove a friend
    static func removeFriend(friendshipId: Int) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/friends/\(friendshipId)",
            method: "DELETE",
            authenticated: true
        )
    }
}
