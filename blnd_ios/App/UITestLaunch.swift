import SwiftUI

/// DEBUG-free launch hook so simulator screenshots can open one screen
/// without a session. Pass `-UITestScreen <name>`.
enum UITestLaunch {
    enum Screen: String {
        case findNowEntry
        case findNowPick
        case findNowReroll
        case findNowSaved
    }

    static var screen: Screen? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-UITestScreen"),
              index + 1 < args.count else { return nil }
        return Screen(rawValue: args[index + 1])
        #else
        return nil
        #endif
    }

    static var usesMockNow: Bool { screen != nil }

    static var prefersGrid: Bool { screen == .findNowEntry }
}

struct UITestHost: View {
    let screen: UITestLaunch.Screen
    @State private var authState = AuthState()
    @State private var tabState = TabState()
    @State private var deepLinkState = DeepLinkState()
    @State private var onboardingState = OnboardingState()

    init(screen: UITestLaunch.Screen) {
        self.screen = screen
        UserDefaults.standard.set(true, forKey: "hasSeenReelsTutorial")
    }

    var body: some View {
        screenView
            .environment(authState)
            .environment(tabState)
            .environment(deepLinkState)
            .environment(onboardingState)
            .preferredColorScheme(.dark)
    }

    @ViewBuilder private var screenView: some View {
        switch screen {
        case .findNowEntry:
            HomeView()
        case .findNowPick:
            FindMovieNowView()
        case .findNowReroll:
            FindMovieNowView(previewExcluded: [NowCatalog.movies[0].tmdbId])
        case .findNowSaved:
            FindMovieNowView(previewSaved: true)
        }
    }
}
