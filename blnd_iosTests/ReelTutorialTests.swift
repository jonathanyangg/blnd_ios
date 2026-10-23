@testable import blnd_ios
import Foundation
import Testing

@MainActor
struct ReelTutorialTests {
    @Test func stepsFollowTheReelCard() {
        let steps = ReelTutorialStep.allCases
        #expect(steps.map(\.title) == [
            "Swipe right",
            "Swipe left",
            "Add to watchlist",
            "Rate with stars",
            "Watch Now",
            "Swipe up",
        ])
        #expect(steps.map(\.target) == [nil, nil, .watchlist, .stars, .watchNow, nil])
        #expect(ReelTutorialStep.interested.nudge.x > 0)
        #expect(ReelTutorialStep.notForMe.nudge.x < 0)
        #expect(ReelTutorialStep.nextMovie.nudge.y < 0)
        #expect(ReelTutorialStep.watchlist.nudge == .rest)
        #expect(ReelTutorialStep.index(for: nil) == 0)
        #expect(ReelTutorialStep.index(for: 99) == steps.count - 1)
    }

    @Test func tutorialShowsOnce() {
        let name = "ReelTutorialTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        #expect(ReelTutorialStore.shouldShow(defaults: defaults))
        ReelTutorialStore.markSeen(defaults: defaults)
        #expect(!ReelTutorialStore.shouldShow(defaults: defaults))
        defaults.removePersistentDomain(forName: name)
    }
}
