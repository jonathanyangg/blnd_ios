import Foundation

/// Groups endpoints: CRUD, members, recommendations, watchlist
enum GroupsAPI {
    /// GET /groups/ — list user's groups
    static func listGroups() async throws -> GroupListResponse {
        try await APIClient.shared.request(
            endpoint: "/groups/",
            authenticated: true
        )
    }

    /// GET /groups/{id} — get group detail with members
    static func getGroup(groupId: Int) async throws -> GroupDetailResponse {
        try await APIClient.shared.request(
            endpoint: "/groups/\(groupId)",
            authenticated: true
        )
    }

    /// GET /groups/{id}/recommendations — AI blend picks
    static func getRecommendations(
        groupId: Int,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> GroupRecommendationsResponse {
        try await APIClient.shared.request(
            endpoint: "/groups/\(groupId)/recommendations"
                + "?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }

    /// POST /groups/{id}/recommendations/feed — infinite scroll blend picks
    static func getFeed(
        groupId: Int,
        exclude: [Int] = [],
        limit: Int = 20
    ) async throws -> GroupRecommendationsResponse {
        let body = GroupFeedRequest(exclude: exclude, limit: limit)
        return try await APIClient.shared.request(
            endpoint: "/groups/\(groupId)/recommendations/feed",
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    /// GET /groups/{id}/watchlist — group watchlist
    static func getWatchlist(
        groupId: Int,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> WatchlistResponse {
        try await APIClient.shared.request(
            endpoint: "/groups/\(groupId)/watchlist"
                + "?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }

    /// POST /groups/{id}/watchlist — add movie to group watchlist
    static func addToWatchlist(
        groupId: Int,
        tmdbId: Int
    ) async throws -> WatchlistMovieResponse {
        let body = AddToWatchlistRequest(tmdbId: tmdbId)
        return try await APIClient.shared.request(
            endpoint: "/groups/\(groupId)/watchlist",
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    /// DELETE /groups/{id}/watchlist/{tmdb_id} — remove from group watchlist
    static func removeFromWatchlist(
        groupId: Int,
        tmdbId: Int
    ) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/groups/\(groupId)/watchlist/\(tmdbId)",
            method: "DELETE",
            authenticated: true
        )
    }
}
