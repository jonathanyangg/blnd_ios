@testable import blnd_ios
import Foundation
import Testing

struct UserFacingErrorTests {
    @Test func offlineAndTimeoutStaySeparate() {
        let offline = UserFacingError.map(URLError(.notConnectedToInternet))
        let wrapped = UserFacingError.map(
            APIError.networkError(URLError(.timedOut))
        )

        #expect(offline.category == .offline)
        #expect(offline.message == "Check your connection and try again.")
        #expect(wrapped.category == .timeout)
        #expect(wrapped.title == "Request timed out")
    }

    @Test func authNotFoundAndServerUseFixedCopy() {
        #expect(UserFacingError.map(APIError.unauthorized).category == .authExpired)
        #expect(UserFacingError.map(APIError.notFound).category == .notFound)
        let server = UserFacingError.map(APIError.serverError(500))
        #expect(server.category == .server)
        #expect(!server.message.contains("500"))
        #expect(!server.title.contains("500"))
    }

    @Test func serverBodyNeverReachesTheCopy() {
        let leaked = "Username already taken SECRET_BODY"
        let validation = UserFacingError.map(APIError.badRequest(leaked))
        let limited = UserFacingError.map(APIError.rateLimited(detail: leaked))
        let unknown = UserFacingError.map(NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: leaked]
        ))

        for copy in [validation, limited, unknown] {
            #expect(!copy.title.contains("SECRET_BODY"))
            #expect(!copy.message.contains("SECRET_BODY"))
            #expect(!copy.message.contains("Username"))
        }
        #expect(validation.category == .validation)
        #expect(UserFacingError.diagnostic(APIError.badRequest(leaked)).contains(leaked))
    }
}
