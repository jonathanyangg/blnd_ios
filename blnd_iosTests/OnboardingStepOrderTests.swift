@testable import blnd_ios
import Testing

struct OnboardingStepOrderTests {
    @Test func letterboxdImportComesRightAfterLovedAndAccount() {
        #expect(OnboardingV2Step.letterboxd.rawValue == OnboardingV2Step.loved.rawValue + 1)
        #expect(OnboardingV2Step.afterAccount == .letterboxd)
    }

    @Test func letterboxdImportIsOptionalNotTutorial() {
        // Skip on the import step advances to the tutorial instead of jumping to friends.
        #expect(OnboardingV2Step.letterboxd.isTutorial == false)
    }
}
