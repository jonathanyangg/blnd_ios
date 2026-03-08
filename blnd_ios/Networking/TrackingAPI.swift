import Foundation

/// Tracking endpoints: watch history + watchlist
enum TrackingAPI {
    /// POST /tracking/ — mark a movie as watched with optional rating/review
    static func trackMovie(
        tmdbId: Int,
        rating: Double? = nil,
        review: String? = nil
    ) async throws -> WatchedMovieResponse {
        let body = TrackMovieRequest(tmdbId: tmdbId, rating: rating, review: review)
        return try await APIClient.shared.request(
            endpoint: "/tracking/",
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    /// GET /tracking/ — get user's watch history
    static func getWatchHistory(
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> WatchHistoryResponse {
        try await APIClient.shared.request(
            endpoint: "/tracking/?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }

    /// GET /tracking/{tmdb_id} — check if a movie has been watched (nil if 404)
    static func getWatchedMovie(tmdbId: Int) async -> WatchedMovieResponse? {
        do {
            return try await APIClient.shared.request(
                endpoint: "/tracking/\(tmdbId)",
                authenticated: true
            )
        } catch APIError.notFound {
            return nil
        } catch {
            return nil
        }
    }

    /// DELETE /tracking/{tmdb_id} — remove a watched movie
    static func deleteWatchedMovie(tmdbId: Int) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/tracking/\(tmdbId)",
            method: "DELETE",
            authenticated: true
        )
    }

    /// GET /tracking/{tmdb_id}/friends — friends who watched this movie
    static func friendsWhoWatched(tmdbId: Int) async throws -> FriendsWhoWatchedResponse {
        try await APIClient.shared.request(
            endpoint: "/tracking/\(tmdbId)/friends",
            authenticated: true
        )
    }

    /// POST /watchlist/ — add a movie to watchlist
    static func addToWatchlist(tmdbId: Int) async throws -> WatchlistMovieResponse {
        let body = AddToWatchlistRequest(tmdbId: tmdbId)
        return try await APIClient.shared.request(
            endpoint: "/watchlist/",
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    /// DELETE /watchlist/{tmdb_id} — remove from watchlist
    static func removeFromWatchlist(tmdbId: Int) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/watchlist/\(tmdbId)",
            method: "DELETE",
            authenticated: true
        )
    }

    /// GET /watchlist/ — get user's watchlist
    static func getWatchlist(
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> WatchlistResponse {
        try await APIClient.shared.request(
            endpoint: "/watchlist/?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }
}
