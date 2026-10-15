import Foundation

/// Message from `{error:{code,message}, detail}`. `detail` is a string.
func apiErrorMessage(from data: Data, fallback: String = "Request failed") -> String {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return fallback
    }
    if let error = json["error"] as? [String: Any],
       let message = error["message"] as? String,
       !message.isEmpty {
        return message
    }
    if let detail = json["detail"] as? String, !detail.isEmpty {
        return detail
    }
    return fallback
}

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case refreshUnavailable
    case badRequest(String)
    case notFound(String)
    case rateLimited(detail: String?)
    case serverError(Int)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .unauthorized: return "Invalid credentials"
        case .refreshUnavailable: return "Couldn't refresh your session - check your connection and try again"
        case let .badRequest(message): return message
        case let .notFound(message): return message
        case let .rateLimited(detail): return detail ?? "Too many requests, try again later"
        case let .serverError(code): return "Server error (\(code))"
        case .decodingError: return "Unexpected response format"
        case let .networkError(error): return error.localizedDescription
        }
    }
}

/// Serializes concurrent token refresh attempts
private actor TokenRefresher {
    private var activeTask: Task<Void, Error>?

    func refresh() async throws {
        if let activeTask {
            try await activeTask.value
            return
        }

        let task = Task<Void, Error> {
            try await self.refreshWithRetries()
        }
        activeTask = task

        do {
            try await task.value
            activeTask = nil
        } catch {
            activeTask = nil
            throw error
        }
    }

    /// One immediate retry for a transient refresh failure. 401 is not retried.
    /// `checkSession` still backs off if the retry also fails.
    private func refreshWithRetries() async throws {
        do {
            try await APIClient.shared.refreshOnce()
        } catch let error as APIError where Self.isTransient(error) {
            try await APIClient.shared.refreshOnce()
        }
    }

    /// 403, 500, and 503 are `.serverError`. Transport failures are `.networkError`.
    private static func isTransient(_ error: APIError) -> Bool {
        switch error {
        case .serverError, .networkError:
            true
        default:
            false
        }
    }
}

final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    static let forceLogoutNotification = Notification.Name(
        "APIClientForceLogout"
    )

    private init() {}

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let tokenRefresher = TokenRefresher()

    /// HTTP session. Tests replace this to fake `/auth/refresh`.
    var session: URLSession = .shared

    /// Proactively refresh the access + refresh token pair.
    /// No-op if no refresh token exists (user not logged in).
    /// A 401 from the refresh call signs the user out. 403, 500, 503, and
    /// network errors keep the stored tokens and retry.
    func refreshTokens() async throws {
        guard KeychainManager.readString(key: "refreshToken") != nil else { return }
        try await refreshOrSignOut()
    }

    /// Runs the refresh call. 401 posts a forced logout. Transient failures
    /// are retried inside the refresher, then surfaced without deleting tokens.
    private func refreshOrSignOut() async throws {
        do {
            try await tokenRefresher.refresh()
        } catch APIError.unauthorized {
            NotificationCenter.default.post(
                name: Self.forceLogoutNotification,
                object: nil
            )
            throw APIError.unauthorized
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.refreshUnavailable
        }
    }

    /// POST /auth/refresh once and store the rotated tokens on success.
    ///
    /// - Throws: `.unauthorized` for 401, `.serverError` for 403/500/503,
    ///   `.networkError` when the transport fails.
    fileprivate func refreshOnce() async throws {
        guard let token = KeychainManager.readString(key: "refreshToken") else {
            throw APIError.unauthorized
        }
        let (http, data) = try await performRequest(
            endpoint: "/auth/refresh",
            method: "POST",
            body: RefreshTokenRequest(refreshToken: token),
            authenticated: false
        )
        switch http.statusCode {
        case 200 ..< 300:
            let response: LoginResponse
            do {
                response = try decoder.decode(LoginResponse.self, from: data)
            } catch {
                throw APIError.decodingError
            }
            KeychainManager.save(key: "accessToken", string: response.accessToken)
            KeychainManager.save(key: "refreshToken", string: response.refreshToken)
        case 401:
            throw APIError.unauthorized
        case 403, 500, 503:
            throw APIError.serverError(http.statusCode)
        default:
            throw mapError(status: http.statusCode, data: data)
        }
    }

    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authenticated: Bool = false
    ) async throws -> T {
        let (http, data) = try await performRequestWithRetry(
            endpoint: endpoint, method: method,
            body: body, authenticated: authenticated
        )
        return try handleResponse(http: http, data: data)
    }

    func requestVoid(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authenticated: Bool = false
    ) async throws {
        let (http, data) = try await performRequestWithRetry(
            endpoint: endpoint, method: method,
            body: body, authenticated: authenticated
        )
        try handleVoidResponse(http: http, data: data)
    }

    private func performRequestWithRetry(
        endpoint: String,
        method: String,
        body: (any Encodable)?,
        authenticated: Bool
    ) async throws -> (HTTPURLResponse, Data) {
        let (http, data) = try await performRequest(
            endpoint: endpoint, method: method,
            body: body, authenticated: authenticated
        )

        guard http.statusCode == 401, authenticated else {
            return (http, data)
        }

        // 401 signs out. 403, 500, 503, and network errors retry, then keep
        // the stored tokens if the refresh still fails.
        try await refreshOrSignOut()

        return try await performRequest(
            endpoint: endpoint, method: method,
            body: body, authenticated: authenticated
        )
    }

    private func performRequest(
        endpoint: String,
        method: String,
        body: (any Encodable)?,
        authenticated: Bool
    ) async throws -> (HTTPURLResponse, Data) {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = KeychainManager.readString(key: "accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(0)
        }

        return (http, data)
    }

    private func handleVoidResponse(http: HTTPURLResponse, data: Data) throws {
        switch http.statusCode {
        case 200 ..< 300:
            return
        default:
            throw mapError(status: http.statusCode, data: data)
        }
    }

    private func handleResponse<T: Decodable>(http: HTTPURLResponse, data: Data) throws -> T {
        switch http.statusCode {
        case 200 ..< 300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError
            }
        default:
            throw mapError(status: http.statusCode, data: data)
        }
    }

    /// Maps HTTP status + body. Errors are `{error:{code,message}, detail}` and `detail` is a string.
    private func mapError(status: Int, data: Data) -> APIError {
        switch status {
        case 401:
            return .unauthorized
        case 404:
            return .notFound(apiErrorMessage(from: data, fallback: "Not found"))
        case 429:
            let detail = apiErrorMessage(from: data, fallback: "")
            return .rateLimited(detail: detail.isEmpty ? nil : detail)
        case 400 ..< 500:
            return .badRequest(parseDetail(from: data))
        default:
            return .serverError(status)
        }
    }

    private func parseDetail(from data: Data) -> String {
        apiErrorMessage(from: data)
    }
}
