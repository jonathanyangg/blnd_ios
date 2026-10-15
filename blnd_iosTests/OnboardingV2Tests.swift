@testable import blnd_ios
import Foundation
import Testing

struct OnboardingV2Tests {
    @Test func fiveLovedMoviesUnlockContinue() {
        #expect(!OnboardingTaste.canContinue(count: 4))
        #expect(OnboardingTaste.canContinue(count: 5))
    }

    @Test func swipeRightIsInterestedAndLeftIsNeutral() {
        #expect(TutorialSwipe.decision(translation: CGFloat(80)) == .interested)
        #expect(TutorialSwipe.decision(translation: CGFloat(-80)) == .notForMe)
        #expect(TutorialSwipe.decision(translation: CGFloat(10)) == nil)
    }
}
