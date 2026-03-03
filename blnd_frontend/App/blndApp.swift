import SwiftUI

@main
struct BlndApp: App {
    @State private var authState = AuthState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authState)
        }
    }
}
