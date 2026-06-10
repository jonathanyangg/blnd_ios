import Foundation

// MARK: - Requests

struct FeedRequest: Encodable {
    let exclude: [Int]
    let limit: Int
}

struct SemanticSearchRequest: Encodable {
    let query: String
    let limit: Int
    let exclude: [Int]
}

struct SemanticSearchResultItem: Decodable, Identifiable {
    let tmdbId: Int
    let title: String
    let year: Int?
    let posterPath: String?
    let genres: [Genre]
    let runtime: Int?
    let voteAverage: Double?
    let matchScore: Double

    var id: Int {
        tmdbId
    }

    var yearString: String {
        year.map { String($0) } ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title, year, genres, runtime
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case matchScore = "match_score"
    }
}

struct SemanticSearchResponse: Decodable {
    let query: String
    let results: [SemanticSearchResultItem]
}

// MARK: - Sort

/// Server-side sort options for paginated movie lists (watched, watchlist, friend watched).
/// Raw values match the backend `?sort=` query param.
enum MovieSortOption: String, CaseIterable, Identifiable {
    case dateDesc = "date_desc"
    case dateAsc = "date_asc"
    case ratingDesc = "rating_desc"
    case ratingAsc = "rating_asc"
    case titleAsc = "title_asc"
    case titleDesc = "title_desc"
    case yearDesc = "year_desc"
    case yearAsc = "year_asc"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .dateDesc: "Recently added"
        case .dateAsc: "Oldest first"
        case .ratingDesc: "Rating: high → low"
        case .ratingAsc: "Rating: low → high"
        case .titleAsc: "Title: A → Z"
        case .titleDesc: "Title: Z → A"
        case .yearDesc: "Year: newest"
        case .yearAsc: "Year: oldest"
        }
    }

    /// Rating sort doesn't apply to watchlist (no ratings on unwatched movies).
    var appliesToWatchlist: Bool {
        self != .ratingDesc && self != .ratingAsc
    }
}

// MARK: - Shared

struct Genre: Codable, Identifiable {
    let id: Int
    let name: String?
}

struct CastMember: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    var stableId: String {
        "\(id)-\(name)"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int.self, forKey: .id)) ?? 0
        name = try container.decode(String.self, forKey: .name)
        character = try container.decodeIfPresent(String.self, forKey: .character)
        profilePath = try container.decodeIfPresent(String.self, forKey: .profilePath)
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
    let commentCount: Int?

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
        case commentCount = "comment_count"
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

// MARK: - Person Search (/movies/search/person)

struct PersonResult: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let profilePath: String?
    let knownForDepartment: String?
    let popularity: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, popularity
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
    }
}

struct PersonSearchResult: Codable {
    let results: [PersonResult]
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case results
        case totalResults = "total_results"
    }
}

// MARK: - Liked Actors (/actors)

struct LikeActorRequest: Encodable {
    let name: String
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case name
        case profilePath = "profile_path"
    }
}

struct LikedActorResponse: Decodable, Identifiable {
    let tmdbPersonId: Int
    let name: String
    let profilePath: String?
    let likedAt: String

    var id: Int {
        tmdbPersonId
    }

    enum CodingKeys: String, CodingKey {
        case tmdbPersonId = "tmdb_person_id"
        case name
        case profilePath = "profile_path"
        case likedAt = "liked_at"
    }
}

struct LikedActorsListResponse: Decodable {
    let results: [LikedActorResponse]
    let total: Int
}

// MARK: - Recommendations (/recommendations/me)

struct RecommendedMovieResponse: Codable, Identifiable {
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
    let matchScore: Double
    let commentCount: Int?

    var id: Int {
        tmdbId
    }

    var yearString: String {
        year.map(String.init) ?? ""
    }

    var scorePercent: Int {
        Int(matchScore * 100)
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
        case matchScore = "match_score"
        case commentCount = "comment_count"
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
