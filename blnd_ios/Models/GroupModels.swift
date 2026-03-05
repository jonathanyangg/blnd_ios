import Foundation

// MARK: - Requests

struct CreateGroupRequest: Encodable {
    let name: String
}

struct AddMemberRequest: Encodable {
    let username: String
}

// MARK: - Responses

struct GroupResponse: Decodable, Identifiable {
    let id: Int
    let name: String
    let createdBy: String
    let memberCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdBy = "created_by"
        case memberCount = "member_count"
        case createdAt = "created_at"
    }
}

struct GroupDetailResponse: Decodable, Identifiable {
    let id: Int
    let name: String
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

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
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
    let director: String?
    let similarity: Double
    let score: Double

    var id: Int {
        tmdbId
    }

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title, year, overview
        case posterPath = "poster_path"
        case director, similarity, score
    }
}

struct GroupRecommendationsResponse: Decodable {
    let results: [GroupRecMovieResponse]
}
