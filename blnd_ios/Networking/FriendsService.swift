import Foundation

/// Mutation layer over FriendsAPI. Every method wraps a write endpoint and
/// invalidates UserActionCache so stale reads can't linger.
/// Read-only endpoints stay on FriendsAPI.
enum FriendsService {
    static func sendRequest(username: String) async throws -> FriendRequestResponse {
        let result = try await APIClient.shared.request(
            endpoint: "/friends/request",
            method: "POST",
            body: SendFriendRequestRequest(addresseeUsername: username),
            authenticated: true
        ) as FriendRequestResponse
        await invalidate()
        return result
    }

    static func acceptRequest(friendshipId: Int) async throws -> FriendRequestResponse {
        let result: FriendRequestResponse = try await APIClient.shared.request(
            endpoint: "/friends/\(friendshipId)/accept",
            method: "POST",
            authenticated: true
        )
        await invalidate()
        return result
    }

    static func rejectRequest(friendshipId: Int) async throws -> FriendRequestResponse {
        let result: FriendRequestResponse = try await APIClient.shared.request(
            endpoint: "/friends/\(friendshipId)/reject",
            method: "POST",
            authenticated: true
        )
        await invalidate()
        return result
    }

    static func withdrawRequest(friendshipId: Int) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/friends/\(friendshipId)/withdraw",
            method: "DELETE",
            authenticated: true
        )
        await invalidate()
    }

    static func removeFriend(friendshipId: Int) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/friends/\(friendshipId)",
            method: "DELETE",
            authenticated: true
        )
        await invalidate()
    }

    /// Block auto-removes any friendship on the server, so it invalidates too.
    static func blockUser(userId: String) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/friends/blocks/\(userId)",
            method: "POST",
            authenticated: true
        )
        await invalidate()
    }

    @MainActor
    private static func invalidate() {
        UserActionCache.shared.invalidateFriends()
    }
}
