import Foundation

/// Timeline and watched-with calls.
///
/// These routes are not on the backend yet. A 404 is surfaced as a friendly
/// unavailable state instead of a broken screen.
///
/// - `GET /tracking/timeline?limit=&offset=`
/// - `GET /auth/users/{user_id}/timeline?limit=&offset=`
/// - `GET /groups/{group_id}/timeline?limit=&offset=`
/// - `GET /tracking/{tmdb_id}/watched-with`
/// - `PUT /tracking/{tmdb_id}/watched-with` with `{ "user_ids": ["..."] }`
enum TimelineAPI {
    static func own(limit: Int = 24, offset: Int = 0) async throws -> TimelinePage {
        try await page(endpoint: "/tracking/timeline", limit: limit, offset: offset)
    }

    static func user(_ userId: String, limit: Int = 24, offset: Int = 0) async throws -> TimelinePage {
        let encoded = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        return try await page(endpoint: "/auth/users/\(encoded)/timeline", limit: limit, offset: offset)
    }

    static func blend(_ groupId: Int, limit: Int = 24, offset: Int = 0) async throws -> TimelinePage {
        try await page(endpoint: "/groups/\(groupId)/timeline", limit: limit, offset: offset)
    }

    /// Friends already tagged on this watch. 404 when the route is missing.
    static func watchedWith(tmdbId: Int) async throws -> [WatchCompanion] {
        let response: WatchedWithResponse = try await APIClient.shared.request(
            endpoint: "/tracking/\(tmdbId)/watched-with",
            authenticated: true
        )
        return response.watchedWith
    }

    /// Replace the friends tagged on this watch.
    static func setWatchedWith(tmdbId: Int, userIds: [String]) async throws {
        let body = SetWatchedWithRequest(userIds: userIds)
        try await APIClient.shared.requestVoid(
            endpoint: "/tracking/\(tmdbId)/watched-with",
            method: "PUT",
            body: body,
            authenticated: true
        )
    }

    private static func page(endpoint: String, limit: Int, offset: Int) async throws -> TimelinePage {
        try await APIClient.shared.request(
            endpoint: "\(endpoint)?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }
}
