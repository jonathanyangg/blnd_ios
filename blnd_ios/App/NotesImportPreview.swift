import Foundation

#if DEBUG
/// Launch with `-NotesImportPreview` to review a fixture list without the server.
enum NotesImportPreviewLaunch {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-NotesImportPreview")
    }

    static let sampleText = "Heat\nThe Godfather\nnot a movie"

    static func install() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NotesImportURLStub.self]
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        config.waitsForConnectivity = false
        APIClient.shared.session = URLSession(configuration: config)
    }
}

/// Answers `POST /import/notes`, `POST /import/notes/commit`, and movie search.
final class NotesImportURLStub: URLProtocol, @unchecked Sendable {
    private static let match = NotesImportResponse(items: [
        NotesImportLine(
            query: "Heat",
            confidence: .high,
            candidates: [
                NotesImportCandidate(tmdbId: 949, title: "Heat", year: 1995, posterPath: nil),
            ]
        ),
        NotesImportLine(
            query: "The Godfather",
            confidence: .low,
            candidates: [
                NotesImportCandidate(tmdbId: 238, title: "The Godfather", year: 1972, posterPath: nil),
                NotesImportCandidate(tmdbId: 240, title: "The Godfather Part II", year: 1974, posterPath: nil),
                NotesImportCandidate(tmdbId: 242, title: "The Godfather Part III", year: 1990, posterPath: nil),
            ]
        ),
        NotesImportLine(query: "not a movie", confidence: .none, candidates: []),
    ])

    private static let recs = [
        NotesImportCandidate(tmdbId: 680, title: "Pulp Fiction", year: 1994, posterPath: nil),
        NotesImportCandidate(tmdbId: 496243, title: "Parasite", year: 2019, posterPath: nil),
    ]

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let client else { return }
        let data = payload(for: url)
        let status = data == nil ? 404 : 200
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data {
            client.urlProtocol(self, didLoad: data)
        }
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func payload(for url: URL) -> Data? {
        switch url.path {
        case "/import/notes":
            return try? JSONEncoder().encode(Self.match)
        case "/import/notes/commit":
            let saved = Self.savedCount(in: request)
            let body = NotesImportCommitResponse(saved: saved, recommendations: Self.recs)
            return try? JSONEncoder().encode(body)
        case "/movies/search":
            return Data(Self.searchJSON.utf8)
        default:
            return nil
        }
    }

    private static func savedCount(in request: URLRequest) -> Int {
        guard let data = bodyData(of: request) else { return 0 }
        struct Payload: Decodable {
            let tmdbIds: [Int]
            enum CodingKeys: String, CodingKey { case tmdbIds = "tmdb_ids" }
        }
        return (try? JSONDecoder().decode(Payload.self, from: data))?.tmdbIds.count ?? 0
    }

    private static func bodyData(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: 4096)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    private static let searchJSON = """
    {"results":[{"tmdb_id":129,"title":"Spirited Away","year":2001,"genres":[],"cast":[]}],"total_results":1}
    """
}
#endif
