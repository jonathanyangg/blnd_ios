@testable import blnd_ios
import Foundation
import SwiftUI
import Testing

struct BlndIOSTests {
    @Test func example() {}

    @Test func resolvesReleaseAPIBaseURL() {
        let url = APIConfig.resolvedBaseURL(["API_BASE_URL": "https://blnd-backend.onrender.com"])
        #expect(url == "https://blnd-backend.onrender.com")
    }

    @Test func resolvesDebugLANAPIBaseURL() {
        let url = APIConfig.resolvedBaseURL(["API_BASE_URL": " http://192.168.7.121:8000 "])
        #expect(url == "http://192.168.7.121:8000")
    }

    @Test func decodeTVSearchResponse() throws {
        let json = """
        {
          "results": [
            {
              "tmdb_id": 1399,
              "title": "Game of Thrones",
              "year": 2011,
              "poster_path": "/tv-poster.jpg",
              "media_type": "tv"
            }
          ],
          "total_results": 1
        }
        """
        let data = Data(json.utf8)

        let response = try JSONDecoder().decode(TVSearchResponse.self, from: data)

        #expect(response.totalResults == 1)
        #expect(response.results.first?.tmdbId == 1399)
        #expect(response.results.first?.title == "Game of Thrones")
        #expect(response.results.first?.year == 2011)
        #expect(response.results.first?.mediaType == .tv)
    }

    @Test func decodeMovieResponseWithoutMediaType() throws {
        let json = """
        {
          "tmdb_id": 550,
          "title": "Fight Club",
          "genres": [],
          "cast": []
        }
        """
        let data = Data(json.utf8)

        let movie = try JSONDecoder().decode(MovieResponse.self, from: data)

        #expect(movie.mediaType == nil)
    }

    @Test func tvBadgeDecisionUsesMediaType() {
        #expect(MovieCard(mediaType: .tv).isTV)
        #expect(!MovieCard(mediaType: .movie).isTV)
        #expect(!MovieCard().isTV)
    }

    @Test func onboardingImportRoutesToFindFriends() {
        #expect(AuthRoute.nextAfterLetterboxdImport == AuthRoute.findFriends)
    }

    @Test @MainActor func hubSkipLeavesImport() {
        var skipped = false
        let hub = BringMoviesHub(router: MovieImportStackRouter(), onSkip: { skipped = true })

        hub.onSkip?()

        #expect(skipped)
    }

    @Test @MainActor func photosAndNotesShareTheReviewRoute() {
        let router = MovieImportStackRouter()
        router.open(.notesReview(NotesImportDraft(source: .photos, text: "Heat", imageCount: 2)))
        router.open(.notesReview(NotesImportDraft(source: .paste, text: "Heat", imageCount: 0)))

        #expect(router.path.count == 2)
    }

    @Test func letterboxdImportUploadsMultipartAndDecodesSummary() async throws {
        let zipData = Data("letterboxd-export".utf8)
        let responseBody = #"{"imported":3,"skipped":1,"failed":0,"failed_titles":[]}"#

        try await withStubbedURLSession { request in
            #expect(request.url?.path == "/import/letterboxd")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            #expect(
                request.value(forHTTPHeaderField: "Content-Type")?
                    .hasPrefix("multipart/form-data; boundary=") == true
            )
            #expect(request.httpBodyStream != nil)

            return (200, Data(responseBody.utf8))
        } operation: { session in
            let summary = try await ImportAPI.upload(
                zipData: zipData,
                session: session,
                accessToken: "test-token"
            )

            #expect(summary.imported == 3)
            #expect(summary.skipped == 1)
            #expect(summary.failed == 0)
            #expect(summary.failedTitles.isEmpty)
        }
    }

    private func withStubbedURLSession(
        handler: @escaping @Sendable (URLRequest) -> (Int, Data),
        operation: @escaping @Sendable (URLSession) async throws -> Void
    ) async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        StubURLProtocol.handler = handler
        defer {
            StubURLProtocol.handler = nil
            session.finishTasksAndInvalidate()
        }

        try await operation(session)
    }
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let (statusCode, data) = handler(request)
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
