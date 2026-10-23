import SwiftUI

/// Which screen the inline onboarding account gate is showing.
enum AccountGateStage: Equatable {
    case signUp
    case chooseUsername

    enum BackAction: Equatable { case closeGate }

    init(pathDepth: Int) {
        self = pathDepth == 0 ? .signUp : .chooseUsername
    }

    init(path: NavigationPath) {
        self.init(pathDepth: path.count)
    }

    /// Back from the gate always returns to the taste picks. It must never pop the onboarding screen itself.
    var backAction: BackAction { .closeGate }
}

/// Sign-up gate shown inside onboarding after the taste picks.
///
/// It must NOT own a NavigationStack: it is already inside the Welcome stack, and a nested stack made the
/// app jump back to Welcome (or show a blank chevron screen) when the gate appeared. The two screens are
/// swapped inline instead, driven by a local path that SignUpView pushes the Apple username step onto.
struct OnboardingAccountGate: View {
    var onReady: () -> Void
    var onSignIn: () -> Void
    @State private var path = NavigationPath()

    var body: some View {
        Group {
            switch AccountGateStage(path: path) {
            case .signUp:
                SignUpView(path: $path, onAccountReady: onReady, onSignIn: onSignIn)
            case .chooseUsername:
                ChooseUsernameView(path: $path, onAccountReady: onReady)
            }
        }
        // The children declare a dismiss-chevron toolbar item; in an inline gate that would pop onboarding.
        .toolbar(.hidden, for: .navigationBar)
    }
}
