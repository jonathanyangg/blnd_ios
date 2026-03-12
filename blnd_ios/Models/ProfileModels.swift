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
