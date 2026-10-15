import SwiftUI

/// Debug-only launch hook so simulator screenshots can open one screen
/// without a session. Pass `-UITestScreen <name>`. Release builds ignore it.
enum UITestLaunch {
    enum Screen: String {
        case notifications
        case notificationsPrivacy
        case notificationsError
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
}

struct UITestHost: View {
    let screen: UITestLaunch.Screen

    var body: some View {
        NavigationStack {
            switch screen {
            case .notifications:
                ActivityFeedView(preview: ActivityPreview.sample())
            case .notificationsPrivacy:
                NotificationsSettingsView(preview: NotificationPrivacyPrefs())
            case .notificationsError:
                ActivityFeedView(forcedError: "No internet connection")
            }
        }
        .environment(AuthState())
        .environment(TabState())
        .environment(DeepLinkState())
        .preferredColorScheme(.dark)
    }
}
