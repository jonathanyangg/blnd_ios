import SwiftUI

/// Routes used by the onboarding NavigationStack.
enum AuthRoute: Hashable {
    case login
    case pickGenres
    case rateMovies
    case createAccount
    case chooseUsername
    case onboardingComplete
    case findFriends
    case forgotPassword
    case letterboxdImport
    case onboardingV2

    static let nextAfterLetterboxdImport = AuthRoute.findFriends
}

/// Landing screen that routes to Sign Up or Login.
/// Where a brand-new Sign in with Apple user goes after choosing a username.
enum AppleNewUserHandoff {
    static let afterUsername = AuthRoute.onboardingV2
}

struct WelcomeView: View {
    @Environment(OnboardingState.self) private var onboardingState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    Text("blnd")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Find what to watch together")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()

                VStack(spacing: 8) {
                    AppButton(label: "Create Account") {
                        Analytics.onboardingStarted()
                        path.append(AuthRoute.onboardingV2)
                    }

                    AppButton(label: "Sign In", style: .ghost) {
                        path.append(AuthRoute.login)
                    }
                }
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background)
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .login:
                    LoginView(path: $path)
                case .pickGenres:
                    PickGenresView(path: $path)
                case .rateMovies:
                    RateMoviesView(path: $path)
                case .createAccount:
                    SignUpView(path: $path)
                case .chooseUsername:
                    ChooseUsernameView(path: $path)
                case .onboardingComplete:
                    OnboardingCompleteView(path: $path)
                case .findFriends:
                    FindFriendsView(path: $path)
                case .forgotPassword:
                    ForgotPasswordView(path: $path)
                case .letterboxdImport:
                    MovieImportFlow(
                        onComplete: { path.append(AuthRoute.nextAfterLetterboxdImport) },
                        onSkip: { path.append(AuthRoute.nextAfterLetterboxdImport) }
                    )
                case .onboardingV2:
                    OnboardingV2View(path: $path)
                }
            }
        }
        .task(id: onboardingState.continueWithV2) {
            guard onboardingState.continueWithV2 else { return }
            path = NavigationPath()
            path.append(AppleNewUserHandoff.afterUsername)
        }
    }
}

#Preview {
    WelcomeView()
        .environment(AuthState())
        .environment(OnboardingState())
}
