import SwiftUI

struct MainTabView: View {
    @Environment(DeepLinkState.self) private var deepLinkState
    @State private var tabState = TabState()

    var body: some View {
        TabView(selection: Binding(
            get: { tabState.selectedTab },
            set: { newTab in
                if newTab == 0, tabState.selectedTab == 0 {
                    tabState.homeRefreshTrigger += 1
                }
                tabState.selectedTab = newTab
            }
        )) {
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(0)

            GroupsListView()
                .tabItem {
                    Image(systemName: "circle.grid.2x2")
                    Text("Blends")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(2)
                .badge(tabState.pendingRequestCount)
        }
        .tint(.white)
        .environment(tabState)
        .task {
            await tabState.refreshPendingCount()
        }
        .onChange(of: tabState.selectedTab) { _, tab in
            if tab == 2 {
                Task { await tabState.refreshPendingCount() }
            }
        }
        .onChange(of: deepLinkState.pending) { _, newValue in
            guard let link = newValue else { return }
            switch link {
            case .friendRequests:
                tabState.selectedTab = 2
                tabState.openNotifications = true
            case .groupDetail:
                tabState.selectedTab = 1
            case .movieDetail:
                tabState.selectedTab = 0
            }
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
