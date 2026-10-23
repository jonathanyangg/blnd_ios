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
    let year: Int?
    let mediaType: MediaType?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case title
        case posterPath = "poster_path"
        case rating, review, liked, year
        case mediaType = "media_type"
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
    let year: Int?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let genres: [Genre]
    let runtime: Int?
    let voteAverage: Double?
    let trailerUrl: String?
    let director: String?
    let cast: [CastMember]
    let tagline: String?
    let addedBy: String?
    let addedDate: String?
    let createdAt: String
    let matchScore: Double?
    let commentCount: Int?
    let mediaType: MediaType?

    var matchPercent: Int? {
        guard let matchScore else { return nil }
        return Int(matchScore * 100)
    }

    var yearString: String {
        year.map { String($0) } ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case title, year, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case genres, runtime
        case voteAverage = "vote_average"
        case trailerUrl = "trailer_url"
        case director, cast, tagline
        case addedBy = "added_by"
        case addedDate = "added_date"
        case createdAt = "created_at"
        case matchScore = "match_score"
        case commentCount = "comment_count"
        case mediaType = "media_type"
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

// MARK: - Activity Feed

struct ActivityFeedItem: Decodable, Identifiable {
    let id: Int
    let userId: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let action: String
    let tmdbId: Int
    let title: String?
    let posterPath: String?
    let rating: Double?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case action
        case tmdbId = "tmdb_id"
        case title
        case posterPath = "poster_path"
        case rating
        case createdAt = "created_at"
    }

    var actionText: String {
        switch action {
        case "rated":
            if let rating {
                let formatted = rating.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", rating)
                    : String(format: "%.1f", rating)
                return "rated \(title ?? "a movie") ★ \(formatted)"
            }
            return "rated \(title ?? "a movie")"
        case "watched":
            return "watched \(title ?? "a movie")"
        case "watchlisted":
            return "added \(title ?? "a movie") to watchlist"
        default:
            return "\(action) \(title ?? "a movie")"
        }
    }

    var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: createdAt) else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 604_800 { return "\(seconds / 86400)d ago" }
        return "\(seconds / 604_800)w ago"
    }
}

struct ActivityFeedResponse: Decodable {
    let results: [ActivityFeedItem]
}
