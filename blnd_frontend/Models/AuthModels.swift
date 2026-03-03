import Foundation

// MARK: - Requests

struct SignupRequest: Encodable {
    let email: String
    let password: String
    let username: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case email, password, username
        case displayName = "display_name"
    }
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

// MARK: - Responses

struct LoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
    }
}

struct UserResponse: Decodable {
    let id: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let tasteBio: String?
    let favoriteGenres: [String]

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case tasteBio = "taste_bio"
        case favoriteGenres = "favorite_genres"
    }
}
