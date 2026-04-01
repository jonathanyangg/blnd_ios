import Foundation

/// Notification endpoints: device registration + preference management
enum NotificationAPI {
    /// POST /notifications/device — register APNs device token with backend
    static func registerDevice(token: String) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/notifications/device",
            method: "POST",
            body: RegisterDeviceRequest(token: token, platform: "ios"),
            authenticated: true
        )
    }

    /// DELETE /notifications/device — unregister device token from backend
    static func unregisterDevice(token: String) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/notifications/device",
            method: "DELETE",
            body: RegisterDeviceRequest(token: token, platform: "ios"),
            authenticated: true
        )
    }

    /// GET /notifications/preferences — read notification preference toggles
    static func getPreferences() async throws -> NotificationPreferences {
        try await APIClient.shared.request(
            endpoint: "/notifications/preferences",
            authenticated: true
        )
    }

    /// PATCH /notifications/preferences — update notification preference toggles (partial)
    static func updatePreferences(
        _ prefs: UpdatePreferencesRequest
    ) async throws -> NotificationPreferences {
        try await APIClient.shared.request(
            endpoint: "/notifications/preferences",
            method: "PATCH",
            body: prefs,
            authenticated: true
        )
    }
}
