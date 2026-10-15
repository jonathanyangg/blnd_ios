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
        #if DEBUG
        if NotesImportPreviewLaunch.isEnabled {
            NotesImportPreviewLaunch.install()
        }
        #endif
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
            Group {
                if let screen = UITestLaunch.screen {
                    UITestHost(screen: screen)
                } else {
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
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                guard NotesShareText.isOpenURL(url) else { return }
                if let text = NotesShareText.consume() {
                    deepLinkState.pendingNotesText = text
                }
            }
        }
    }
}
