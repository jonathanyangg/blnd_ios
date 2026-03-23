import Foundation

// MARK: - Requests

struct FeedRequest: Encodable {
    let exclude: [Int]
    let limit: Int
}

// MARK: - Shared

struct Genre: Codable, Identifiable {
    let id: Int?
    let name: String?
}

struct CastMember: Codable, Identifiable {
    let id: Int?
    let name: String
    let character: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
}

// MARK: - Movie Detail (/movies/{id})

struct MovieResponse: Codable, Identifiable {
    let tmdbId: Int
    let title: String
    let year: Int?
    let overview: String?
    let posterPath: String?
    let genres: [Genre]
    let runtime: Int?
    let voteAverage: Double?
    let trailerUrl: String?
    let director: String?
    let cast: [CastMember]
    let tagline: String?
    let backdropPath: String?
    let imdbId: String?
    let matchScore: Double?

    var id: Int {
        tmdbId
    }

    var matchPercent: Int? {
        guard let matchScore else { return nil }
        return Int(matchScore * 100)
    }

    var yearString: String {
        guard let year else { return "" }
        return String(year)
    }

    var runtimeFormatted: String? {
        guard let runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title, year, overview
        case posterPath = "poster_path"
        case genres, runtime
        case voteAverage = "vote_average"
        case trailerUrl = "trailer_url"
        case director, cast, tagline
        case backdropPath = "backdrop_path"
        case imdbId = "imdb_id"
        case matchScore = "match_score"
    }
}

// MARK: - Search / Trending (/movies/search, /movies/trending)

struct MovieSearchResult: Decodable {
    let results: [MovieResponse]
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case results
        case totalResults = "total_results"
    }
}

// MARK: - Recommendations (/recommendations/me)

struct RecommendedMovieResponse: Codable, Identifiable {
    let tmdbId: Int
    let title: String
    let year: Int?
    let overview: String?
    let posterPath: String?
    let genres: [Genre]
    let director: String?
    let similarity: Double
    let score: Double

    var id: Int {
        tmdbId
    }

    var yearString: String {
        year.map(String.init) ?? ""
    }

    var scorePercent: Int {
        Int(score * 100)
    }

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title, year, overview
        case posterPath = "poster_path"
        case genres, director, similarity, score
    }
}

struct HiddenMovieResponse: Decodable, Identifiable {
    let tmdbId: Int
    let title: String
    let year: Int?
    let posterPath: String?
    let hiddenAt: String

    var id: Int {
        tmdbId
    }

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title, year
        case posterPath = "poster_path"
        case hiddenAt = "hidden_at"
    }
}

struct HiddenMoviesListResponse: Decodable {
    let results: [HiddenMovieResponse]
    let total: Int
}

struct RecommendationsResponse: Decodable {
    let results: [RecommendedMovieResponse]
    let tasteBio: String?

    enum CodingKeys: String, CodingKey {
        case results
        case tasteBio = "taste_bio"
    }
}
