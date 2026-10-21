@testable import blnd_ios
import Foundation
import Testing

struct ReelSwipeDecisionTests {
    @Test func rightSwipeIsInterestedNotWatchlist() {
        let decision = reelSwipeDecision(deltaX: 121, deltaY: 0, threshold: 120)
        #expect(decision == .interested)
    }

    @Test func leftSwipeIsNotForMe() {
        let decision = reelSwipeDecision(deltaX: -121, deltaY: 10, threshold: 120)
        #expect(decision == .notForMe)
    }

    @Test func errorEnvelopeUsesMessageAndStringDetail() {
        let body = Data(
            """
            {"error":{"code":"NOT_FOUND","message":"Movie not marked not for me"},"detail":"Movie not marked not for me"}
            """.utf8
        )
        #expect(apiErrorMessage(from: body) == "Movie not marked not for me")
    }

    @Test func verticalDragIsIgnored() {
        let decision = reelSwipeDecision(deltaX: 130, deltaY: 100, threshold: 120)
        #expect(decision == .ignore)
    }

    @Test func shortSwipeIsIgnored() {
        let decision = reelSwipeDecision(deltaX: 119, deltaY: 0, threshold: 120)
        #expect(decision == .ignore)
    }
}
