@testable import blnd_ios
import Foundation
import Testing

struct BlndIOSTests {
    @Test func onboardingImportRoutesToFindFriends() {
        #expect(AuthRoute.nextAfterLetterboxdImport == AuthRoute.findFriends)
    }

    @Test func hubSkipLeavesImport() {
        var skipped = false
        let hub = BringMoviesHub(router: MovieImportStackRouter(), onSkip: { skipped = true })

        hub.onSkip?()

        #expect(skipped)
    }

    @Test func photosAndNotesShareTheReviewRoute() {
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
