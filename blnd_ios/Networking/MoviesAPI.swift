import Foundation

/// Movie endpoints: search, trending, detail
enum MoviesAPI {
    static func search(query: String, page: Int = 1) async throws -> MovieSearchResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await APIClient.shared.request(
            endpoint: "/movies/search?query=\(encoded)&page=\(page)",
            authenticated: true
        )
    }

    static func trending(page: Int = 1) async throws -> MovieSearchResult {
        try await APIClient.shared.request(
            endpoint: "/movies/trending?page=\(page)",
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
    static func getRecommendations(
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> RecommendationsResponse {
        try await APIClient.shared.request(
            endpoint: "/recommendations/me?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }

    static func refresh(limit: Int = 20) async throws -> RecommendationsResponse {
        try await APIClient.shared.request(
            endpoint: "/recommendations/me?limit=\(limit)&refresh=true",
            authenticated: true
        )
    }
}
