import Foundation

/// Timeline and watched-with calls.
///
/// Pages use a cursor. Pass `cursor` from the previous `next_cursor`, and stop
/// when `next_cursor` is null. There is no offset.
///
/// - `GET /tracking/timeline?cursor=`
/// - `GET /auth/users/{user_id}/timeline?cursor=`
/// - `GET /groups/{group_id}/timeline?cursor=`
/// - `GET /tracking/{tmdb_id}/watched-with`
/// - `PUT /tracking/{tmdb_id}/watched-with` with `{ "user_ids": [...] }` (max 50; `[]` clears)
enum TimelineAPI {
    static let pageSize = 20

    static func own(cursor: String? = nil) async throws -> TimelinePage {
        try await page(endpoint: "/tracking/timeline", cursor: cursor)
    }

    static func user(_ userId: String, cursor: String? = nil) async throws -> TimelinePage {
        let encoded = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        return try await page(endpoint: "/auth/users/\(encoded)/timeline", cursor: cursor)
    }

    static func blend(_ groupId: Int, cursor: String? = nil) async throws -> TimelinePage {
        try await page(endpoint: "/groups/\(groupId)/timeline", cursor: cursor)
    }

    /// People already tagged on this watch.
    static func watchedWith(tmdbId: Int) async throws -> [TimelinePerson] {
        let response: WatchedWithResponse = try await APIClient.shared.request(
            endpoint: "/tracking/\(tmdbId)/watched-with",
            authenticated: true
        )
        return response.watchedWith
    }

    /// Replace the people tagged on this watch. `[]` clears them. More than 50 is rejected.
    @discardableResult
    static func setWatchedWith(tmdbId: Int, userIds: [String]) async throws -> [TimelinePerson] {
        if userIds.count > DiaryCopy.maxCompanions {
            throw APIError.badRequest(
                APIFieldError(
                    code: nil,
                    issues: [APIIssue(field: nil, text: DiaryCopy.companionCapMessage)],
                    raw: DiaryCopy.companionCapMessage,
                    opensPaywall: false
                )
            )
        }
        let body = SetWatchedWithRequest(userIds: userIds)
        let response: WatchedWithResponse = try await APIClient.shared.request(
            endpoint: "/tracking/\(tmdbId)/watched-with",
            method: "PUT",
            body: body,
            authenticated: true
        )
        return response.watchedWith
    }

    private static func page(endpoint: String, cursor: String?) async throws -> TimelinePage {
        var items = [URLQueryItem(name: "limit", value: String(pageSize))]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        var components = URLComponents()
        components.queryItems = items
        let query = components.percentEncodedQuery ?? ""
        return try await APIClient.shared.request(
            endpoint: "\(endpoint)?\(query)",
            authenticated: true
        )
    }
}
