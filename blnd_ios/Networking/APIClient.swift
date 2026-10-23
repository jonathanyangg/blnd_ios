import Foundation

/// One parsed client error. `raw` is for logs. Views use `UserFacingError`, not `raw`.
struct APIIssue: Equatable, Sendable {
    var field: String?
    var text: String
}

struct APIFieldError: Equatable, Sendable {
    var code: String?
    var issues: [APIIssue]
    var raw: String
    var opensPaywall: Bool

    var field: String? { issues.first?.field }
}

/// Message from `{error:{code,message}, detail}`. `detail` may be a string.
func apiErrorMessage(from data: Data, fallback: String = "Request failed") -> String {
    let raw = APIFieldError.parse(data).raw
    return raw.isEmpty ? fallback : raw
}

enum APIErrorEnvelope {
    static func message(in data: Data) -> String? {
        let raw = APIFieldError.parse(data).raw
        return raw == "Request failed" ? nil : raw
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case refreshUnavailable
    case badRequest(APIFieldError)
    case notFound
    case rateLimited(detail: String?)
    case serverError(Int)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        UserFacingError.map(self).message
    }

    var opensPaywall: Bool {
        if case let .badRequest(info) = self { return info.opensPaywall }
        return false
    }

    /// Reads `{error: {code, message}, detail}` first. Older bodies that only
    /// have `detail` (string, `{code, message}`, or a 422 list) still parse.
    static func decode(status: Int, data: Data) -> APIError {
        let info = APIFieldError.parse(data)
        switch status {
        case 401:
            return .unauthorized
        case 404:
            return .notFound
        case 429:
            return .rateLimited(detail: info.raw)
        case 400 ..< 500:
            return .badRequest(info)
        default:
            return .serverError(status, info.raw.isEmpty ? nil : info.raw)
        }
    }
}

extension APIFieldError {
    private static let paywallCodes: Set<String> = [
        "PREMIUM_REQUIRED", "PAYMENT_REQUIRED", "FREE_GROUP_CAP",
    ]

    static func parse(_ data: Data) -> APIFieldError {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return APIFieldError(code: nil, issues: [], raw: "Request failed", opensPaywall: false)
        }
        if let error = json["error"] as? [String: Any], let code = error["code"] as? String {
            let message = (error["message"] as? String) ?? (json["detail"] as? String) ?? ""
            return make(code: code, message: message)
        }
        if let detail = json["detail"] as? String {
            return make(code: nil, message: detail)
        }
        if let detail = json["detail"] as? [String: Any] {
            let code = (detail["code"] as? String)?.uppercased()
            let message = detail["message"] as? String ?? ""
            return make(code: code, message: message)
        }
        if let detail = json["detail"] as? [[String: Any]] {
            let issues = detail.map { issue in
                let msg = (issue["msg"] as? String ?? "invalid")
                    .replacingOccurrences(of: "Value error, ", with: "")
                return APIIssue(field: fieldName(issue["loc"]), text: msg)
            }
            let raw = issues.map { issue in
                issue.field.map { "\($0): \(issue.text)" } ?? issue.text
            }.joined(separator: "; ")
            return APIFieldError(
                code: "VALIDATION_ERROR",
                issues: issues,
                raw: raw.isEmpty ? "Request failed" : raw,
                opensPaywall: false
            )
        }
        return APIFieldError(code: nil, issues: [], raw: "Request failed", opensPaywall: false)
    }

    private static func make(code: String?, message: String) -> APIFieldError {
        let normalized = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let code = (normalized?.isEmpty == false) ? normalized : nil
        let raw = message.isEmpty ? "Request failed" : message
        let legacyPaywall = code == nil && (
            raw.localizedCaseInsensitiveContains("blnd+")
                || raw.localizedCaseInsensitiveContains("upgrade")
        )
        return APIFieldError(
            code: code,
            issues: split(message),
            raw: raw,
            opensPaywall: paywallCodes.contains(code ?? "") || legacyPaywall
        )
    }

    private static func split(_ message: String) -> [APIIssue] {
        let parts = message.split(separator: ";", omittingEmptySubsequences: true)
        if parts.isEmpty { return [APIIssue(field: nil, text: message)] }
        return parts.map { part in
            let piece = part.trimmingCharacters(in: .whitespaces)
            guard let range = piece.range(of: ": ") else {
                return APIIssue(field: nil, text: piece)
            }
            let loc = String(piece[..<range.lowerBound])
            let text = String(piece[range.upperBound...])
            return APIIssue(field: fieldName(loc), text: text)
        }
    }

    private static func fieldName(_ loc: Any?) -> String? {
        let parts: [String]
        if let loc = loc as? [Any] {
            parts = loc.compactMap { $0 as? String }
        } else if let loc = loc as? String {
            parts = loc.split(separator: ".").map(String.init)
        } else {
            return nil
        }
        return parts.last { $0 != "body" && $0 != "query" }
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

    /// Runs the refresh call. A 401 posts a forced logout only when the
    /// refresh token that failed is still the one in the Keychain. Transient
    /// failures are retried inside the refresher, then surfaced without deleting tokens.
    private func refreshOrSignOut() async throws {
        let attempted = KeychainManager.readString(key: "refreshToken")
        do {
            try await tokenRefresher.refresh()
        } catch APIError.unauthorized {
            if KeychainManager.readString(key: "refreshToken") == attempted {
                NotificationCenter.default.post(
                    name: Self.forceLogoutNotification,
                    object: nil
                )
            }
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
            throw APIError.serverError(http.statusCode, nil)
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

    private func mapError(status: Int, data: Data) -> APIError {
        APIError.decode(status: status, data: data)
    }
}
