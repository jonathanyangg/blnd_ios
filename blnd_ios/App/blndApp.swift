import PostHog
import RevenueCat
import SwiftUI

@main
struct BlndApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authState = AuthState()
    @State private var onboardingState = OnboardingState()
    @State private var deepLinkState = DeepLinkState()

    init() {
        let config = PostHogConfig(apiKey: "phc_o8gysMyjwxqas8WBdUzNXwiQN9xsASDhCyetHvfnSWY5")
        config.captureScreenViews = true
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: "appl_XsVFffVINQJHsPlnmgVzYyPAleP")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                ContentView()
                    .environment(authState)
                    .environment(onboardingState)
                    .environment(deepLinkState)
                    .onAppear {
                        appDelegate.deepLinkState = deepLinkState
                    }
            }
            .preferredColorScheme(.dark)
        }
    }
}
