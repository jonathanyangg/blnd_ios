import Foundation

// MARK: - Comment Response

struct CommentResponse: Codable, Identifiable {
    let id: Int
    let tmdbId: Int
    let parentId: Int?
    let replyToUserId: String?
    let replyToUsername: String?
    let userId: String?
    let username: String?
    let avatarUrl: String?
    var body: String
    var likeCount: Int
    var likedByMe: Bool
    let commenterRating: Double?
    var isEdited: Bool
    let createdAt: String
    var replies: [CommentResponse]

    enum CodingKeys: String, CodingKey {
        case id, body, replies, username
        case tmdbId = "tmdb_id"
        case parentId = "parent_id"
        case replyToUserId = "reply_to_user_id"
        case replyToUsername = "reply_to_username"
        case userId = "user_id"
        case avatarUrl = "avatar_url"
        case likeCount = "like_count"
        case likedByMe = "liked_by_me"
        case commenterRating = "commenter_rating"
        case isEdited = "is_edited"
        case createdAt = "created_at"
    }

    var isDeleted: Bool {
        userId == nil
    }

    var displayUsername: String {
        username ?? "deleted"
    }

    var timeAgo: String {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        guard let date = withFraction.date(from: createdAt) ?? plain.date(from: createdAt) else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        if seconds < 604_800 { return "\(seconds / 86400)d" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Comments List Response

struct CommentsListResponse: Codable {
    let results: [CommentResponse]
    let total: Int
}

// MARK: - Like Response

struct LikeResponse: Codable {
    let likeCount: Int
    let likedByMe: Bool

    enum CodingKeys: String, CodingKey {
        case likeCount = "like_count"
        case likedByMe = "liked_by_me"
    }
}

// MARK: - Requests

struct CreateCommentRequest: Encodable {
    let tmdbId: Int
    let body: String

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case body
    }
}

struct CreateReplyRequest: Encodable {
    let body: String
}

struct EditCommentRequest: Encodable {
    let body: String
}
