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

struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct UpdateProfileRequest: Encodable {
    let username: String?
    let displayName: String?
    let tasteBio: String?
    let favoriteGenres: [String]?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case tasteBio = "taste_bio"
        case favoriteGenres = "favorite_genres"
        case avatarUrl = "avatar_url"
    }
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

struct UserSearchResult: Decodable, Identifiable {
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

struct UserSearchResponse: Decodable {
    let results: [UserSearchResult]
}

// MARK: - OAuth

struct OAuthRequest: Encodable {
    let provider: String
    let idToken: String
    let nonce: String?
    let authorizationCode: String?

    enum CodingKeys: String, CodingKey {
        case provider
        case idToken = "id_token"
        case nonce
        case authorizationCode = "authorization_code"
    }
}

struct OAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let isNewUser: Bool
    let appleRefreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
        case isNewUser = "is_new_user"
        case appleRefreshToken = "apple_refresh_token"
    }
}

// MARK: - Onboarding

struct RatedMovieRequest: Encodable {
    let tmdbId: Int
    let rating: Double

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case rating
    }
}

struct CompleteOnboardingRequest: Encodable {
    let username: String
    let displayName: String?
    let favoriteGenres: [String]?
    let ratedMovies: [RatedMovieRequest]?
    let appleRefreshToken: String?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case favoriteGenres = "favorite_genres"
        case ratedMovies = "rated_movies"
        case appleRefreshToken = "apple_refresh_token"
    }
}

struct CompleteOnboardingResponse: Decodable {
    let userId: String
    let username: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
    }
}

struct UserResponse: Decodable {
    let id: String
    let username: String?
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
