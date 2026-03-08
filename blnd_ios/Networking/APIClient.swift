import Foundation

/// Pydantic 422 validation error shape
private struct ValidationErrorDetail: Decodable {
    let msg: String
}

private struct ValidationErrorResponse: Decodable {
    let detail: [ValidationErrorDetail]
}

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case badRequest(String)
    case notFound
    case rateLimited
    case serverError(Int)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .unauthorized: return "Invalid credentials"
        case let .badRequest(message): return message
        case .notFound: return "Not found"
        case .rateLimited: return "Too many requests, try again later"
        case let .serverError(code): return "Server error (\(code))"
        case .decodingError: return "Unexpected response format"
        case let .networkError(error): return error.localizedDescription
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authenticated: Bool = false
    ) async throws -> T {
        let (http, data) = try await performRequest(
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
        let (http, data) = try await performRequest(
            endpoint: endpoint, method: method,
            body: body, authenticated: authenticated
        )
        try handleVoidResponse(http: http, data: data)
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
            (data, response) = try await URLSession.shared.data(for: request)
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
                print("[APIClient] Decoding \(T.self) failed: \(error)")
                if let raw = String(data: data, encoding: .utf8) {
                    print("[APIClient] Raw response: \(raw.prefix(500))")
                }
                throw APIError.decodingError
            }
        default:
            throw mapError(status: http.statusCode, data: data)
        }
    }

    /// Maps HTTP status + response body to an APIError.
    /// Handles all FastAPI error shapes:
    ///   - 400/409: {"detail": "string"}
    ///   - 422:     {"detail": [{"msg": "string", ...}]}
    ///   - 429:     plain text (rate limit)
    private func mapError(status: Int, data: Data) -> APIError {
        switch status {
        case 401:
            return .unauthorized
        case 404:
            return .notFound
        case 429:
            return .rateLimited
        case 400 ..< 500:
            return .badRequest(parseDetail(from: data))
        default:
            return .serverError(status)
        }
    }

    /// Parses error detail from FastAPI response body.
    /// Tries {"detail": "string"} first, then {"detail": [{"msg": ...}]}.
    private func parseDetail(from data: Data) -> String {
        // Shape 1: {"detail": "Username already taken"}
        if let obj = try? decoder.decode([String: String].self, from: data), let detail = obj["detail"] {
            return detail
        }
        // Shape 2: {"detail": [{"msg": "String should have at most 250 characters", ...}]}
        if let obj = try? decoder.decode(ValidationErrorResponse.self, from: data) {
            let messages = obj.detail.map(\.msg)
            return messages.joined(separator: ". ")
        }
        return "Request failed"
    }
}
