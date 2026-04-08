import PostHog
import SwiftUI

@main
struct BlndApp: App {
    @State private var authState = AuthState()
    @State private var onboardingState = OnboardingState()

    init() {
        let config = PostHogConfig(apiKey: "phc_o8gysMyjwxqas8WBdUzNXwiQN9xsASDhCyetHvfnSWY5")
        config.captureScreenViews = true
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                ContentView()
                    .environment(authState)
                    .environment(onboardingState)
            }
            .preferredColorScheme(.dark)
        }
    }
}
