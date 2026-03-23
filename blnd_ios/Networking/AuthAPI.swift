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

    /// POST /auth/refresh — exchange refresh token for new tokens
    static func refresh(
        refreshToken: String
    ) async throws -> LoginResponse {
        let body = RefreshTokenRequest(refreshToken: refreshToken)
        return try await APIClient.shared.request(
            endpoint: "/auth/refresh",
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

    /// POST /auth/oauth — exchange provider ID token for BLND session
    static func oauth(
        provider: String,
        idToken: String,
        nonce: String?,
        authorizationCode: String? = nil
    ) async throws -> OAuthResponse {
        let body = OAuthRequest(
            provider: provider,
            idToken: idToken,
            nonce: nonce,
            authorizationCode: authorizationCode
        )
        return try await APIClient.shared.request(
            endpoint: "/auth/oauth",
            method: "POST",
            body: body
        )
    }

    /// POST /auth/complete-onboarding — create profile for new OAuth user
    static func completeOnboarding(
        username: String,
        displayName: String?,
        favoriteGenres: [String]?,
        ratedMovies: [RatedMovieRequest]?,
        appleRefreshToken: String? = nil
    ) async throws -> CompleteOnboardingResponse {
        let body = CompleteOnboardingRequest(
            username: username,
            displayName: displayName,
            favoriteGenres: favoriteGenres,
            ratedMovies: ratedMovies,
            appleRefreshToken: appleRefreshToken
        )
        return try await APIClient.shared.request(
            endpoint: "/auth/complete-onboarding",
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    /// DELETE /auth/account — permanently delete user account
    static func deleteAccount() async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/auth/account",
            method: "DELETE",
            authenticated: true
        )
    }

    /// PATCH /auth/profile — update profile fields
    static func updateProfile(
        username: String? = nil,
        displayName: String? = nil,
        tasteBio: String? = nil,
        favoriteGenres: [String]? = nil,
        avatarUrl: String? = nil
    ) async throws -> UserResponse {
        let body = UpdateProfileRequest(
            username: username,
            displayName: displayName,
            tasteBio: tasteBio,
            favoriteGenres: favoriteGenres,
            avatarUrl: avatarUrl
        )
        return try await APIClient.shared.request(
            endpoint: "/auth/profile",
            method: "PATCH",
            body: body,
            authenticated: true
        )
    }
}
