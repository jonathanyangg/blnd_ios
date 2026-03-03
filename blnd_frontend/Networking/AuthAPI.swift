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
}
