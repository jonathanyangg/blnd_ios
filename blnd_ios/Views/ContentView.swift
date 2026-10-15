import SwiftUI
import UserNotifications

/// Root view that gates on authentication phase.
/// Shows a splash screen during cold-launch session check, then routes
/// to onboarding or main tab view based on AuthPhase.
struct ContentView: View {
    @Environment(AuthState.self) var authState
    @Environment(DeepLinkState.self) private var deepLinkState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if let screen = UITestLaunch.screen {
            UITestHost(screen: screen)
        } else {
            root
                .preferredColorScheme(.dark)
                .onChange(of: authState.phase) { _, newPhase in
                    if newPhase == .authenticated {
                        requestNotificationPermission()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    pullSharedNotes()
                    guard authState.phase == .authenticated else { return }
                    UIApplication.shared.applicationIconBadgeNumber = 0
                    Task {
                        try? await APIClient.shared.refreshTokens()
                        try? await NotificationAPI.resetBadge()
                    }
                }
        }
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        if NotesImportPreviewLaunch.isEnabled {
            NavigationStack {
                notesImportReview(text: NotesImportPreviewLaunch.sampleText)
            }
        } else if ProcessInfo.processInfo.arguments.contains("UI_TEST_LETTERBOXD_IMPORT") {
            MovieImportUITestHost()
        } else {
            sessionRoot
        }
        #else
        sessionRoot
        #endif
    }

    private var sessionRoot: some View {
        let notesText = deepLinkState.pendingNotesText
        return Group {
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
        .task {
            if authState.isCheckingSession {
                await authState.checkSession()
            }
        }
        .onAppear { pullSharedNotes() }
        .fullScreenCover(
            item: Binding(
                get: {
                    // Read the live value. A captured snapshot stays non-nil after dismiss and reopens the cover.
                    _ = notesText
                    return deepLinkState.pendingNotesText.map(NotesImportLaunch.init)
                },
                set: { deepLinkState.pendingNotesText = $0?.text }
            )
        ) { launch in
            NavigationStack {
                notesImportReview(text: launch.text) {
                    deepLinkState.pendingNotesText = nil
                }
            }
        }
    }

    /// Opens a note the Share Extension left in the app group.
    private func pullSharedNotes() {
        #if DEBUG
        if NotesImportPreviewLaunch.isEnabled { return }
        #endif
        guard deepLinkState.pendingNotesText == nil else { return }
        if let text = NotesShareText.consume() {
            deepLinkState.pendingNotesText = text
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
        .environment(DeepLinkState())
        .onAppear { state.phase = .authenticated }
}

#Preview("Onboarding") {
    let state = AuthState()
    ContentView()
        .environment(state)
        .environment(DeepLinkState())
        .onAppear { state.phase = .unauthenticated }
}
