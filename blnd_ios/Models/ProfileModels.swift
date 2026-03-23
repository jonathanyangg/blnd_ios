import Foundation

// MARK: - Responses

/// Full public profile stats for a friend — returned by GET /auth/users/{id}/profile
struct PublicProfileResponse: Decodable {
    let id: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let watchedCount: Int
    let friendsCount: Int
    let blendsCount: Int

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case watchedCount = "watched_count"
        case friendsCount = "friends_count"
        case blendsCount = "blends_count"
    }
}

/// A single watched movie item from a friend's public watch history
struct PublicWatchedMovieResponse: Decodable, Identifiable {
    let tmdbId: Int
    let title: String
    let posterPath: String?
    let rating: Double?

    /// Identifiable conformance via tmdbId
    var id: Int {
        tmdbId
    }

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title
        case posterPath = "poster_path"
        case rating
    }
}

/// Paginated envelope for a friend's watched movies — returned by GET /auth/users/{id}/watched
struct PublicWatchedListResponse: Decodable {
    let results: [PublicWatchedMovieResponse]
    let total: Int
}

/// A single friend entry from the public friends list — no friendshipId (public view only)
struct PublicFriendResponse: Decodable, Identifiable, Hashable {
    let id: String
    let username: String
    let displayName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

/// Envelope for a friend's public friends list — returned by GET /auth/users/{id}/friends
struct PublicFriendsListResponse: Decodable {
    let friends: [PublicFriendResponse]
}

// MARK: - Genre Taste

/// A single genre score entry from the taste radar — returned inside GenreTasteResponse
struct GenreScore: Decodable, Identifiable {
    let name: String
    let score: Double
    let watchCount: Int
    let avgRating: Double?

    var id: String {
        name
    }

    enum CodingKeys: String, CodingKey {
        case name, score
        case watchCount = "watch_count"
        case avgRating = "avg_rating"
    }
}

/// Genre taste breakdown — returned by GET /auth/me/taste
struct GenreTasteResponse: Decodable {
    let genres: [GenreScore]
    let totalRated: Int

    enum CodingKeys: String, CodingKey {
        case genres
        case totalRated = "total_rated"
    }
}
