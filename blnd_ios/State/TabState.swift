import SwiftUI

@Observable
class TabState {
    var selectedTab = 0
    var navigationReset = 0
    var homeRefreshTrigger = 0
    var pendingRequestCount = 0

    func switchTab(_ tab: Int) {
        navigationReset += 1
        selectedTab = tab
    }

    func refreshPendingCount() async {
        do {
            let response =
                try await FriendsAPI.getPendingRequests()
            pendingRequestCount = response.incoming.count
        } catch {
            // Non-fatal
        }
    }
}
