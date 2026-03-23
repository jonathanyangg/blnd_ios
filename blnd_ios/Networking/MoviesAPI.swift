import Foundation

/// Movie endpoints: search, trending, detail
enum MoviesAPI {
    /// GET /movies/discover — top movies by genre with softmax sampling
    static func discover(
        genres: [String],
        exclude: Set<Int> = []
    ) async throws -> MovieSearchResult {
        let joined = genres.joined(separator: ",")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        var endpoint = "/movies/discover?genres=\(joined)"
        if !exclude.isEmpty {
            endpoint += "&exclude=\(exclude.map(String.init).joined(separator: ","))"
        }
        return try await APIClient.shared.request(
            endpoint: endpoint,
            authenticated: true
        )
    }

    static func search(query: String, page: Int = 1) async throws -> MovieSearchResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await APIClient.shared.request(
            endpoint: "/movies/search?query=\(encoded)&page=\(page)",
            authenticated: true
        )
    }

    static func trending(exclude: Set<Int> = []) async throws -> MovieSearchResult {
        var endpoint = "/movies/trending"
        if !exclude.isEmpty {
            endpoint += "?exclude=\(exclude.map(String.init).joined(separator: ","))"
        }
        return try await APIClient.shared.request(
            endpoint: endpoint,
            authenticated: true
        )
    }

    static func topRated(exclude: Set<Int> = []) async throws -> MovieSearchResult {
        var endpoint = "/movies/top-rated"
        if !exclude.isEmpty {
            endpoint += "?exclude=\(exclude.map(String.init).joined(separator: ","))"
        }
        return try await APIClient.shared.request(
            endpoint: endpoint,
            authenticated: true
        )
    }

    static func getMovie(tmdbId: Int) async throws -> MovieResponse {
        try await APIClient.shared.request(
            endpoint: "/movies/\(tmdbId)",
            authenticated: true
        )
    }
}

/// Recommendation endpoints
enum RecommendationsAPI {
    /// POST /recommendations/me/feed — infinite scroll feed with exclude list
    static func getFeed(
        exclude: [Int] = [],
        limit: Int = 50
    ) async throws -> RecommendationsResponse {
        let body = FeedRequest(exclude: exclude, limit: limit)
        return try await APIClient.shared.request(
            endpoint: "/recommendations/me/feed",
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    static func getRecommendations(
        limit: Int = 60,
        offset: Int = 0
    ) async throws -> RecommendationsResponse {
        try await APIClient.shared.request(
            endpoint: "/recommendations/me?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }

    static func refresh(limit: Int = 60) async throws -> RecommendationsResponse {
        try await APIClient.shared.request(
            endpoint: "/recommendations/me/refresh?limit=\(limit)",
            method: "POST",
            authenticated: true
        )
    }

    /// POST /recommendations/{tmdb_id}/hide — exclude from future recs
    static func hideMovie(
        tmdbId: Int
    ) async throws -> HiddenMovieResponse {
        try await APIClient.shared.request(
            endpoint: "/recommendations/\(tmdbId)/hide",
            method: "POST",
            authenticated: true
        )
    }

    /// DELETE /recommendations/{tmdb_id}/hide — re-allow in recs
    static func unhideMovie(tmdbId: Int) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/recommendations/\(tmdbId)/hide",
            method: "DELETE",
            authenticated: true
        )
    }

    /// GET /recommendations/hidden — list hidden movies
    static func getHidden(
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> HiddenMoviesListResponse {
        try await APIClient.shared.request(
            endpoint: "/recommendations/hidden"
                + "?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }
}
