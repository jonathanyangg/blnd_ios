import SwiftUI

@main
struct BlndApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authState = AuthState()
    @State private var onboardingState = OnboardingState()
    @State private var deepLinkState = DeepLinkState()

    var body: some Scene {
        WindowGroup {
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
