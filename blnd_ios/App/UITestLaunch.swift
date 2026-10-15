import SwiftUI

/// Debug-only launch hook so simulator screenshots can open one screen
/// without a session. Pass `-UITestScreen <name>`. Release builds ignore it.
enum UITestLaunch {
    enum Screen: String {
        case findNowEntry
        case findNowPick
        case findNowReroll
        case findNowSaved
        case onboardValue1
        case onboardValue2
        case onboardTaste
        case tutorialSwipe
        case tutorialRate
        case tutorialMatch
        case tutorialBlends
        case tutorialNow
        case tutorialLetterboxd
        case tutorialTaste
        case onboardFriends
        case onboardFeed
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

    static var prefersGrid: Bool {
        screen == .findNowEntry || screen == .onboardFeed
    }
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
        case .findNowEntry, .onboardFeed:
            HomeView()
        case .findNowPick:
            FindMovieNowView()
        case .findNowReroll:
            FindMovieNowView(previewExcluded: [NowCatalog.movies[0].tmdbId])
        case .findNowSaved:
            FindMovieNowView(previewSaved: true)
        case .onboardValue1:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .valueTonight)
        case .onboardValue2:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .valueTaste)
        case .onboardTaste:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .loved)
        case .tutorialSwipe:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .swipe)
        case .tutorialRate:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .rate)
        case .tutorialMatch:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .match)
        case .tutorialBlends:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .blends)
        case .tutorialNow:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .now)
        case .tutorialLetterboxd:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .letterboxd)
        case .tutorialTaste:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .taste)
        case .onboardFriends:
            OnboardingV2View(path: .constant(NavigationPath()), preview: .friends)
        }
    }
}
