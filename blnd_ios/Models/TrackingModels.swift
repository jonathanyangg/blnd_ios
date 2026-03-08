import Foundation

// MARK: - Requests

struct TrackMovieRequest: Encodable {
    let tmdbId: Int
    let rating: Double?
    let review: String?

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case rating, review
    }
}

struct AddToWatchlistRequest: Encodable {
    let tmdbId: Int

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
    }
}

// MARK: - Responses

struct WatchedMovieResponse: Decodable, Identifiable {
    let id: Int
    let tmdbId: Int
    let title: String
    let posterPath: String?
    let rating: Double?
    let review: String?
    let liked: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case title
        case posterPath = "poster_path"
        case rating, review, liked
        case createdAt = "created_at"
    }
}

struct WatchHistoryResponse: Decodable {
    let results: [WatchedMovieResponse]
    let total: Int
}

struct WatchlistMovieResponse: Decodable, Identifiable {
    let id: Int
    let tmdbId: Int
    let title: String
    let posterPath: String?
    let addedBy: String?
    let addedDate: String?
    let createdAt: String
    let matchScore: Double?

    var matchPercent: Int? {
        guard let matchScore else { return nil }
        return Int(matchScore * 100)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case title
        case posterPath = "poster_path"
        case addedBy = "added_by"
        case addedDate = "added_date"
        case createdAt = "created_at"
        case matchScore = "match_score"
    }
}

struct WatchlistResponse: Decodable {
    let results: [WatchlistMovieResponse]
    let total: Int
}
