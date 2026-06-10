import Foundation

// MARK: - Requests

struct GroupFeedRequest: Encodable {
    let exclude: [Int]
    let limit: Int
}

struct CreateGroupRequest: Encodable {
    let name: String
}

struct AddMemberRequest: Encodable {
    let username: String
}

struct UpdateGroupRequest: Encodable {
    let name: String?
}

// MARK: - Responses

struct GroupResponse: Decodable, Identifiable {
    let id: Int
    let name: String
    let createdBy: String
    let memberCount: Int
    let memberAvatars: [String?]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdBy = "created_by"
        case memberCount = "member_count"
        case memberAvatars = "member_avatars"
        case createdAt = "created_at"
    }
}

struct GroupDetailResponse: Decodable, Identifiable {
    let id: Int
    var name: String
    let createdBy: String
    let members: [GroupMemberResponse]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, members
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct GroupMemberResponse: Decodable, Identifiable {
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

struct GroupListResponse: Decodable {
    let groups: [GroupResponse]
}

struct GroupRecMovieResponse: Decodable, Identifiable {
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
        year.map { String($0) } ?? ""
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

struct GroupRecommendationsResponse: Decodable {
    let results: [GroupRecMovieResponse]
}
