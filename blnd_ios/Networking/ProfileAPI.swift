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
        offset: Int = 0,
        query: String? = nil,
        sort: MovieSortOption? = nil
    ) async throws -> PublicWatchedListResponse {
        var endpoint = "/auth/users/\(userId)/watched?limit=\(limit)&offset=\(offset)"
        if let query, !query.isEmpty {
            endpoint += "&q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        if let sort {
            endpoint += "&sort=\(sort.rawValue)"
        }
        return try await APIClient.shared.request(
            endpoint: endpoint,
            authenticated: true
        )
    }

    /// GET /auth/users/{id}/taste — fetch a friend's genre taste breakdown (requires friendship)
    static func getPublicTaste(userId: String) async throws -> GenreTasteResponse {
        try await APIClient.shared.request(
            endpoint: "/auth/users/\(userId)/taste",
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

    /// GET /auth/me/taste — fetch the current user's genre taste breakdown (8-axis radar data)
    static func getGenreTaste() async throws -> GenreTasteResponse {
        try await APIClient.shared.request(
            endpoint: "/auth/me/taste",
            authenticated: true
        )
    }
}
