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

    /// POST /notifications/badge/reset — reset badge count to 0
    static func resetBadge() async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/notifications/badge/reset",
            method: "POST",
            authenticated: true
        )
    }

    /// GET /notifications/inbox — get unified notification feed
    static func getInbox(limit: Int = 30, offset: Int = 0) async throws -> InboxResponse {
        try await APIClient.shared.request(
            endpoint: "/notifications/inbox?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }

    /// POST /notifications/inbox/read — mark all inbox items as read
    static func markInboxRead() async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/notifications/inbox/read",
            method: "POST",
            authenticated: true
        )
    }

    /// PATCH /notifications/preferences — update notification preference toggles (partial).
    /// Sends the richer body first. A 4xx means this server only stores the five booleans.
    static func updatePreferences(
        _ prefs: UpdatePreferencesRequest
    ) async throws -> NotificationPreferences {
        do {
            return try await sendPreferences(prefs, includeExtensions: true)
        } catch APIError.badRequest {
            return try await sendPreferences(prefs, includeExtensions: false)
        }
    }

    private static func sendPreferences(
        _ prefs: UpdatePreferencesRequest,
        includeExtensions: Bool
    ) async throws -> NotificationPreferences {
        let body = PreferencePatch(request: prefs, includeExtensions: includeExtensions)
        return try await APIClient.shared.request(
            endpoint: "/notifications/preferences",
            method: "PATCH",
            body: body,
            authenticated: true
        )
    }
}

private struct PreferencePatch: Encodable {
    let request: UpdatePreferencesRequest
    let includeExtensions: Bool

    func encode(to encoder: Encoder) throws {
        try request.encode(to: encoder, includeExtensions: includeExtensions)
    }
}
