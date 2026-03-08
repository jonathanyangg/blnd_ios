import Foundation

enum AuthAPI {
    static func signup(
        email: String,
        password: String,
        username: String,
        displayName: String?
    ) async throws -> LoginResponse {
        let body = SignupRequest(
            email: email,
            password: password,
            username: username,
            displayName: displayName
        )
        return try await APIClient.shared.request(
            endpoint: "/auth/signup",
            method: "POST",
            body: body
        )
    }

    static func login(
        email: String,
        password: String
    ) async throws -> LoginResponse {
        let body = LoginRequest(email: email, password: password)
        return try await APIClient.shared.request(
            endpoint: "/auth/login",
            method: "POST",
            body: body
        )
    }

    static func me() async throws -> UserResponse {
        try await APIClient.shared.request(
            endpoint: "/auth/me",
            authenticated: true
        )
    }

    /// GET /auth/users/search?q= — search users by username prefix
    static func searchUsers(query: String) async throws -> UserSearchResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await APIClient.shared.request(
            endpoint: "/auth/users/search?q=\(encoded)",
            authenticated: true
        )
    }

    /// PATCH /auth/profile — update profile fields
    static func updateProfile(
        displayName: String? = nil,
        tasteBio: String? = nil,
        favoriteGenres: [String]? = nil
    ) async throws -> UserResponse {
        let body = UpdateProfileRequest(
            displayName: displayName,
            tasteBio: tasteBio,
            favoriteGenres: favoriteGenres
        )
        return try await APIClient.shared.request(
            endpoint: "/auth/profile",
            method: "PATCH",
            body: body,
            authenticated: true
        )
    }
}
