import Foundation

/// Movie endpoints: search, trending, detail
enum MoviesAPI {
    /// GET /movies/discover — top movies by genre or actor with softmax sampling
    static func discover(
        genres: [String] = [],
        withCast: Int? = nil,
        exclude: Set<Int> = []
    ) async throws -> MovieSearchResult {
        var params: [String] = []
        if !genres.isEmpty {
            let joined = genres.joined(separator: ",")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            params.append("genres=\(joined)")
        }
        if let castId = withCast {
            params.append("with_cast=\(castId)")
        }
        if !exclude.isEmpty {
            params.append("exclude=\(exclude.map(String.init).joined(separator: ","))")
        }
        let endpoint = "/movies/discover?\(params.joined(separator: "&"))"
        return try await APIClient.shared.request(
            endpoint: endpoint,
            authenticated: true
        )
    }

    /// GET /movies/search/person — search for actors by name
    static func searchPerson(query: String) async throws -> PersonSearchResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await APIClient.shared.request(
            endpoint: "/movies/search/person?query=\(encoded)",
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

    /// GET /movies/person/{person_id}/credits — actor filmography with softmax sampling
    static func getPersonCredits(
        personId: Int,
        exclude: Set<Int> = []
    ) async throws -> MovieSearchResult {
        var endpoint = "/movies/person/\(personId)/credits"
        if !exclude.isEmpty {
            endpoint += "?exclude=\(exclude.map(String.init).joined(separator: ","))"
        }
        return try await APIClient.shared.request(
            endpoint: endpoint,
            authenticated: true
        )
    }

    static func getStreaming(
        tmdbId: Int,
        country: String = "us"
    ) async throws -> StreamingAvailabilityResponse {
        try await APIClient.shared.request(
            endpoint: "/movies/\(tmdbId)/streaming?country=\(country)",
            authenticated: true
        )
    }
}

/// TV endpoints (backend feature flag)
enum TVAPI {
    /// GET /tv/search — only available when the backend TV flag is enabled.
    static func search(query: String, page: Int = 1) async throws -> TVSearchResponse {
        try await APIClient.shared.request(
            endpoint: "/tv/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&page=\(page)",
            authenticated: true
        )
    }
}

/// Actor endpoints
enum ActorsAPI {
    /// POST /actors/{person_id}/like
    static func likeActor(
        personId: Int,
        name: String,
        profilePath: String?
    ) async throws -> LikedActorResponse {
        let body = LikeActorRequest(name: name, profilePath: profilePath)
        return try await APIClient.shared.request(
            endpoint: "/actors/\(personId)/like",
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    /// DELETE /actors/{person_id}/like
    static func unlikeActor(personId: Int) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/actors/\(personId)/like",
            method: "DELETE",
            authenticated: true
        )
    }

    /// GET /actors/liked
    static func getLikedActors(
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> LikedActorsListResponse {
        try await APIClient.shared.request(
            endpoint: "/actors/liked?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }
}

/// Recommendation endpoints
enum RecommendationsAPI {
    /// POST /recommendations/me/feed — infinite scroll feed with exclude list
    static func getFeed(
        exclude: [Int] = [],
        limit: Int = 20
    ) async throws -> RecommendationsResponse {
        let body = FeedRequest(exclude: exclude, limit: limit)
        return try await APIClient.shared.request(
            endpoint: "/recommendations/me/feed",
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    static func semanticSearch(
        query: String,
        limit: Int = 30,
        exclude: [Int] = []
    ) async throws -> SemanticSearchResponse {
        let body = SemanticSearchRequest(query: query, limit: limit, exclude: exclude)
        return try await APIClient.shared.request(
            endpoint: "/recommendations/semantic-discover",
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

    /// GET /recommendations/now — one movie and a reason.
    /// `exclude` is the re-roll list of tmdb ids.
    static func findNow(
        genre: String?,
        exclude: [Int]
    ) async throws -> NowPickResponse {
        try await APIClient.shared.request(
            endpoint: NowPickQuery.endpoint(genre: genre, exclude: exclude),
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
