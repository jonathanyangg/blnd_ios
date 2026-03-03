import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case badRequest(String)
    case serverError(Int)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .unauthorized: return "Invalid credentials"
        case let .badRequest(message): return message
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
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(0)
        }

        return try handleResponse(http: http, data: data)
    }

    private func handleResponse<T: Decodable>(http: HTTPURLResponse, data: Data) throws -> T {
        switch http.statusCode {
        case 200 ..< 300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError
            }
        case 401:
            throw APIError.unauthorized
        case 400 ..< 500:
            let detail = (try? decoder.decode([String: String].self, from: data))?["detail"]
            throw APIError.badRequest(detail ?? "Request failed")
        default:
            throw APIError.serverError(http.statusCode)
        }
    }
}
