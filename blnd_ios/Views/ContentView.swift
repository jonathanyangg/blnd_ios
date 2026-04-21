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
        .onChange(of: authState.phase) { _, newPhase in
            if newPhase == .authenticated {
                requestNotificationPermission()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, authState.phase == .authenticated {
                UIApplication.shared.applicationIconBadgeNumber = 0
                Task { try? await NotificationAPI.resetBadge() }
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

/// Animated boot logo: types "blend" character-by-character, then backspaces the 'e'
/// to land on "blnd" — mirrors the web hero animation in blnd_frontend/Hero.tsx.
private struct LaunchLogo: View {
    @State private var typedCount = 0
    @State private var eDeleted = false
    @State private var cursorPos: Int?
    @State private var cursorBlink = true

    private let font: Font = .system(size: 56, weight: .bold)
    private let cursorWidth: CGFloat = 3
    private let cursorHeight: CGFloat = 52

    var body: some View {
        HStack(spacing: 0) {
            cursorSlot(position: 0)
            letter("b", index: 0)
            cursorSlot(position: 1)
            letter("l", index: 1)
            cursorSlot(position: 2)
            eSlot
            cursorSlot(position: 3)
            letter("n", index: 3)
            cursorSlot(position: 4)
            letter("d", index: 4)
            cursorSlot(position: 5)
        }
        .font(font)
        .foregroundStyle(.white)
        .task { await runSequence() }
    }

    private func letter(_ text: String, index: Int) -> some View {
        Text(text)
            .opacity(typedCount > index ? 1 : 0)
    }

    @ViewBuilder
    private var eSlot: some View {
        if !eDeleted {
            Text("e")
                .opacity(typedCount > 2 ? 1 : 0)
                .transition(
                    .asymmetric(
                        insertion: .identity,
                        removal: .scale(scale: 0.01, anchor: .leading)
                            .combined(with: .opacity)
                    )
                )
        }
    }

    private func cursorSlot(position: Int) -> some View {
        Color.clear
            .frame(width: 0)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(.white)
                    .frame(width: cursorWidth, height: cursorHeight)
                    .opacity(cursorPos == position && cursorBlink ? 1 : 0)
            }
    }

    private func runSequence() async {
        async let typing: Void = runTyping()
        async let blink: Void = runBlink()
        _ = await (typing, blink)
    }

    private func runTyping() async {
        try? await Task.sleep(for: .milliseconds(300))
        cursorPos = 0

        try? await Task.sleep(for: .milliseconds(450))
        for index in 0 ..< 5 {
            withAnimation(.easeOut(duration: 0.12)) {
                typedCount = index + 1
                cursorPos = index + 1
            }
            try? await Task.sleep(for: .milliseconds(310))
        }

        try? await Task.sleep(for: .milliseconds(500))
        cursorPos = 4
        try? await Task.sleep(for: .milliseconds(260))
        cursorPos = 3
        try? await Task.sleep(for: .milliseconds(320))

        withAnimation(.easeInOut(duration: 0.32)) {
            eDeleted = true
        }
        cursorPos = nil
    }

    private func runBlink() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(530))
            cursorBlink.toggle()
        }
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
