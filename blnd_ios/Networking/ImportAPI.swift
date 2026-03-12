import Foundation

/// Multipart file upload to `POST /import/letterboxd`.
///
/// Uses a direct `URLSession` request instead of `APIClient` so that
/// `Content-Type: multipart/form-data` is preserved (APIClient always sets JSON).
enum ImportAPI {
    /// Uploads a Letterboxd export ZIP and returns the import summary.
    ///
    /// - Parameter zipData: Raw bytes of the Letterboxd export archive.
    /// - Returns: `ImportSummaryResponse` with imported/skipped/failed counts.
    /// - Throws: `APIError.unauthorized` if no access token is found in Keychain,
    ///   `APIError.serverError` for non-2xx responses, or a `DecodingError` for
    ///   unexpected response shapes.
    static func upload(zipData: Data) async throws -> ImportSummaryResponse {
        guard let token = KeychainManager.readString(key: "accessToken") else {
            throw APIError.unauthorized
        }

        guard let url = URL(string: APIConfig.baseURL + "/import/letterboxd") else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = buildBody(zipData: zipData, boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(0)
        }

        guard 200 ..< 300 ~= http.statusCode else {
            throw APIError.serverError(http.statusCode)
        }

        return try JSONDecoder().decode(ImportSummaryResponse.self, from: data)
    }

    // MARK: - Private

    private static func buildBody(zipData: Data, boundary: String) -> Data {
        var body = Data()
        // Part header (RFC 7578 — CRLF line endings throughout)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"export.zip\"\r\n")
        body.append("Content-Type: application/zip\r\n\r\n")
        body.append(zipData)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }
}

// MARK: - Data helper

private extension Data {
    mutating func append(_ string: String) {
        if let encoded = string.data(using: .utf8) {
            append(encoded)
        }
    }
}
