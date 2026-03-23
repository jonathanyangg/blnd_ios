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

struct UpdateTrackingRequest: Encodable {
    let rating: Double?

    enum CodingKeys: String, CodingKey {
        case rating
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

struct WatchlistStatusResponse: Decodable {
    let personal: Bool
    let groupIds: [Int]

    enum CodingKeys: String, CodingKey {
        case personal
        case groupIds = "group_ids"
    }
}

struct FriendWatchedResponse: Decodable, Identifiable {
    let userId: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let rating: Double?
    let review: String?
    let watchedDate: String?

    var id: String {
        userId
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case rating, review
        case watchedDate = "watched_date"
    }

    var asFriendResponse: FriendResponse {
        FriendResponse(
            friendshipId: nil,
            id: userId,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl
        )
    }
}

struct FriendsWhoWatchedResponse: Decodable {
    let results: [FriendWatchedResponse]
    let total: Int
}
