import Foundation

/// Movie endpoints: search, trending, detail
enum MoviesAPI {
    /// GET /movies/discover — top movies by genre or actor with softmax sampling
    static func discover(
        genres: [String] = [],
        withCast: Int? = nil,
        exclude: Set<Int> = [],
        filter: CatalogFilter = CatalogFilter()
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
        let base = params.isEmpty
            ? "/movies/discover"
            : "/movies/discover?\(params.joined(separator: "&"))"
        let endpoint = filter.appending(to: base)
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

    static func search(
        query: String,
        page: Int = 1,
        filter: CatalogFilter = CatalogFilter()
    ) async throws -> MovieSearchResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await APIClient.shared.request(
            endpoint: filter.appending(to: "/movies/search?query=\(encoded)&page=\(page)"),
            authenticated: true
        )
    }

    static func trending(
        exclude: Set<Int> = [],
        filter: CatalogFilter = CatalogFilter()
    ) async throws -> MovieSearchResult {
        var endpoint = "/movies/trending"
        if !exclude.isEmpty {
            endpoint += "?exclude=\(exclude.map(String.init).joined(separator: ","))"
        }
        return try await APIClient.shared.request(
            endpoint: filter.appending(to: endpoint),
            authenticated: true
        )
    }

    static func topRated(
        exclude: Set<Int> = [],
        filter: CatalogFilter = CatalogFilter()
    ) async throws -> MovieSearchResult {
        var endpoint = "/movies/top-rated"
        if !exclude.isEmpty {
            endpoint += "?exclude=\(exclude.map(String.init).joined(separator: ","))"
        }
        endpoint = filter.appending(to: endpoint)
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
    /// GET /tv/search. Years are sent. The path already means TV, so media_type is omitted.
    static func search(
        query: String,
        page: Int = 1,
        filter: CatalogFilter = CatalogFilter()
    ) async throws -> TVSearchResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await APIClient.shared.request(
            endpoint: filter.yearsOnly.appending(to: "/tv/search?query=\(encoded)&page=\(page)"),
            authenticated: true
        )
    }
}

enum CatalogSearch {
    /// Movies stay on `/movies/search`. TV uses `/tv/search`. All calls both and merges.
    static func search(
        query: String,
        page: Int = 1,
        filter: CatalogFilter
    ) async throws -> [MovieResponse] {
        let years = filter.yearsOnly
        switch filter.media {
        case .movies:
            return try await MoviesAPI.search(query: query, page: page, filter: years).results
        case .tv:
            let shows = try await TVAPI.search(query: query, page: page, filter: years)
            return shows.results.map { MovieResponse(show: $0) }
        case .all:
            async let movies = MoviesAPI.search(query: query, page: page, filter: years)
            async let shows = TVAPI.search(query: query, page: page, filter: years)
            let movieRows = try await movies.results
            let showRows: [MovieResponse]
            do {
                showRows = try await shows.results.map { MovieResponse(show: $0) }
            } catch APIError.notFound {
                showRows = []
            }
            return merge(movies: movieRows, shows: showRows)
        }
    }

    static func merge(movies: [MovieResponse], shows: [MovieResponse]) -> [MovieResponse] {
        var seen = Set<Int>()
        return (movies + shows).filter { seen.insert($0.tmdbId).inserted }
    }
}

extension MovieResponse {
    init(show: TVShowResponse) {
        self.init(
            tmdbId: show.tmdbId,
            title: show.title,
            year: show.year,
            overview: show.overview,
            posterPath: show.posterPath,
            genres: [],
            runtime: nil,
            voteAverage: nil,
            trailerUrl: nil,
            director: nil,
            cast: [],
            tagline: nil,
            backdropPath: nil,
            imdbId: nil,
            matchScore: nil,
            commentCount: nil,
            mediaType: show.mediaType
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
        limit: Int = 20,
        filter: CatalogFilter = CatalogFilter()
    ) async throws -> RecommendationsResponse {
        let body = FeedRequest(exclude: exclude, limit: limit)
        return try await APIClient.shared.request(
            endpoint: filter.appending(to: "/recommendations/me/feed"),
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    static func semanticSearch(
        query: String,
        limit: Int = 30,
        exclude: [Int] = [],
        filter: CatalogFilter = CatalogFilter()
    ) async throws -> SemanticSearchResponse {
        let body = SemanticSearchRequest(query: query, limit: limit, exclude: exclude)
        return try await APIClient.shared.request(
            endpoint: filter.appending(to: "/recommendations/semantic-discover"),
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

    static func refresh(
        limit: Int = 60,
        filter: CatalogFilter = CatalogFilter()
    ) async throws -> RecommendationsResponse {
        try await APIClient.shared.request(
            endpoint: filter.appending(to: "/recommendations/me/refresh?limit=\(limit)"),
            method: "POST",
            authenticated: true
        )
    }

    /// GET /recommendations/now. A 404 means nothing matched the filter.
    static func findNow(
        genre: String? = nil,
        exclude: [Int] = [],
        filter: CatalogFilter = CatalogFilter()
    ) async throws -> NowPickResponse {
        try await APIClient.shared.request(
            endpoint: FindNowCatalogFilter.endpoint(
                genre: genre,
                exclude: exclude,
                filter: filter
            ),
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
