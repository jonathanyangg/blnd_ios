import SwiftUI

/// Routes used by the onboarding NavigationStack.
enum AuthRoute: Hashable {
    case login
    case pickGenres
    case rateMovies
    case createAccount
    case chooseUsername
    case onboardingComplete
}

/// Landing screen that routes to Sign Up or Login.
struct WelcomeView: View {
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
                    OnboardingCompleteView()
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
