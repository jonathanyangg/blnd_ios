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

    static let nextAfterLetterboxdImport = AuthRoute.findFriends
}

/// Landing screen that routes to Sign Up or Login.
struct WelcomeView: View {
    @State private var path = NavigationPath()
    #if DEBUG
    private let isLetterboxdImportUITest = ProcessInfo.processInfo.arguments.contains(
        "UI_TEST_LETTERBOXD_IMPORT"
    )
    #endif

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
                        path.append(AuthRoute.pickGenres)
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
            .onAppear {
                #if DEBUG
                if isLetterboxdImportUITest {
                    path.append(AuthRoute.letterboxdImport)
                }
                #endif
            }
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
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environment(AuthState())
        .environment(OnboardingState())
}
