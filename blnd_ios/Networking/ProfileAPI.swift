import Foundation

/// Public profile endpoints — stats, watched movies, and friends list for any user
enum ProfileAPI {
    /// GET /auth/users/{id}/profile — fetch a friend's public profile stats (watched, friends, blends counts)
    static func getPublicProfile(userId: String) async throws -> PublicProfileResponse {
        try await APIClient.shared.request(
            endpoint: "/auth/users/\(userId)/profile",
            authenticated: true
        )
    }

    /// GET /auth/users/{id}/watched — fetch a friend's watched movies (paginated)
    static func getPublicWatched(
        userId: String,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> PublicWatchedListResponse {
        try await APIClient.shared.request(
            endpoint: "/auth/users/\(userId)/watched?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }

    /// GET /auth/users/{id}/friends — fetch a friend's public friends list
    static func getPublicFriends(userId: String) async throws -> PublicFriendsListResponse {
        try await APIClient.shared.request(
            endpoint: "/auth/users/\(userId)/friends",
            authenticated: true
        )
    }
}
