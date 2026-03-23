import SwiftUI

/// Root view that gates on authentication phase.
/// Shows a splash screen during cold-launch session check, then routes
/// to onboarding or main tab view based on AuthPhase.
struct ContentView: View {
    @Environment(AuthState.self) var authState

    var body: some View {
        Group {
            if authState.isCheckingSession {
                launchScreen
            } else {
                switch authState.phase {
                case .unauthenticated, .onboardingPending:
                    OnboardingView()
                case .authenticated:
                    MainTabView()
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if authState.isCheckingSession {
                await authState.checkSession()
            }
        }
    }

    /// Splash screen shown during cold-launch session resolution.
    /// Prevents flash of WelcomeView when the user is actually authenticated.
    private var launchScreen: some View {
        VStack {
            Spacer()
            Text("blnd")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

#Preview("Authenticated") {
    let state = AuthState()
    ContentView()
        .environment(state)
        .onAppear { state.phase = .authenticated }
}

#Preview("Onboarding") {
    let state = AuthState()
    ContentView()
        .environment(state)
        .onAppear { state.phase = .unauthenticated }
}
