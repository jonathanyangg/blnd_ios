@testable import blnd_ios
import Testing

struct ReelSwipeDecisionTests {
    @Test func rightSwipeIsInterestedNotWatchlist() {
        let decision = reelSwipeDecision(deltaX: 121, deltaY: 0, threshold: 120)
        #expect(decision == .interested)
    }

    @Test func leftSwipeHides() {
        let decision = reelSwipeDecision(deltaX: -121, deltaY: 10, threshold: 120)
        #expect(decision == .hide)
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
