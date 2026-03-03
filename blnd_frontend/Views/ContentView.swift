import SwiftUI

/// Root view that gates on authentication status.
/// Shows onboarding flow for unauthenticated users, main tab view for authenticated users.
struct ContentView: View {
    @Environment(AuthState.self) var authState

    var body: some View {
        Group {
            if authState.isAuthenticated {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Authenticated") {
    ContentView()
        .environment(AuthState())
}

#Preview("Onboarding") {
    let state = AuthState()
    ContentView()
        .environment(state)
        .onAppear { state.isAuthenticated = false }
}
