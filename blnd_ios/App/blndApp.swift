import SwiftUI

@main
struct BlndApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authState = AuthState()
    @State private var onboardingState = OnboardingState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authState)
                .environment(onboardingState)
        }
    }
}
