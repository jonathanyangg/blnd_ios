import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var deepLinkState: DeepLinkState?

    // MARK: - UIApplicationDelegate

    func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "apnsDeviceToken")
        Task { try? await NotificationAPI.registerDevice(token: token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        UNUserNotificationCenter.current().setBadgeCount(0)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String {
            switch type {
            case "friend_request":
                deepLinkState?.pending = .friendRequests
            case "group_invite":
                if let idStr = userInfo["group_id"] as? String, let groupId = Int(idStr) {
                    deepLinkState?.pending = .groupDetail(groupId: groupId)
                }
            case "friend_activity", "friend_accepted":
                if let idStr = userInfo["tmdb_id"] as? String, let tmdbId = Int(idStr) {
                    deepLinkState?.pending = .movieDetail(tmdbId: tmdbId)
                }
            case "group_watchlist":
                if let idStr = userInfo["group_id"] as? String, let groupId = Int(idStr) {
                    deepLinkState?.pending = .groupDetail(groupId: groupId)
                }
            case "weekly_digest":
                break
            default:
                break
            }
        }
        completionHandler()
    }
}
