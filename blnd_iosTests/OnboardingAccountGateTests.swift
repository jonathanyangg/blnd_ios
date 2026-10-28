@testable import blnd_ios
import Foundation
import SwiftUI
import Testing

/// The sign-up gate used to be a NavigationStack nested inside the onboarding stack, which bounced a new
/// user back to Welcome. It is now an inline view that keeps its own stage; these pin that routing.
@MainActor
struct OnboardingAccountGateTests {
    @Test func gateStartsOnSignUp() {
        #expect(AccountGateStage(pathDepth: 0) == .signUp)
    }

    @Test func appleHandoffShowsChooseUsernameInline() {
        #expect(AccountGateStage(pathDepth: 1) == .chooseUsername)
        #expect(AccountGateStage(pathDepth: 3) == .chooseUsername)
    }

    @Test func gateStageFollowsAuthRoutePath() {
        var path = NavigationPath()
        #expect(AccountGateStage(path: path) == .signUp)
        path.append(AuthRoute.chooseUsername)
        #expect(AccountGateStage(path: path) == .chooseUsername)
        path.removeLast()
        #expect(AccountGateStage(path: path) == .signUp)
    }

    @Test func backFromGateReturnsToTastePicksInsteadOfLeavingOnboarding() {
        // From either gate stage, back must close the gate (stay in onboarding), never pop to Welcome.
        #expect(AccountGateStage.signUp.backAction == .closeGate)
        #expect(AccountGateStage.chooseUsername.backAction == .closeGate)
    }
}
