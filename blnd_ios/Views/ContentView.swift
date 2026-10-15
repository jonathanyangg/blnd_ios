import SwiftUI
import UserNotifications

/// Root view that gates on authentication phase.
/// Shows a splash screen during cold-launch session check, then routes
/// to onboarding or main tab view based on AuthPhase.
struct ContentView: View {
    @Environment(AuthState.self) var authState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if showsPaywallScreenshot {
                PaywallView(source: .manual)
            } else if authState.isCheckingSession {
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
        .onChange(of: authState.phase) { _, newPhase in
            if newPhase == .authenticated {
                requestNotificationPermission()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, authState.phase == .authenticated {
                UIApplication.shared.applicationIconBadgeNumber = 0
                Task {
                    try? await APIClient.shared.refreshTokens()
                    try? await NotificationAPI.resetBadge()
                }
            }
        }
    }

    /// Soft-ask for notification permission, then register for APNs if granted.
    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Debug-only. Launch with `-PaywallScreenshot` to capture the paywall.
    private var showsPaywallScreenshot: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PaywallScreenshot")
        #else
        false
        #endif
    }

    /// Splash screen shown during cold-launch session resolution.
    /// Prevents flash of WelcomeView when the user is actually authenticated.
    private var launchScreen: some View {
        VStack {
            Spacer()
            LaunchLogo()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

private struct LaunchLogo: View {
    var body: some View {
        Text("blnd")
            .font(.system(size: 56, weight: .bold))
            .foregroundStyle(.white)
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
