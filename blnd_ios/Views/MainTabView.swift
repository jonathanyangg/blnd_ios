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
                        .accessibilityIdentifier("home.tab.home")
                }
                .tag(0)

            FriendsListView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Friends")
                }
                .tag(1)
                .badge(tabState.pendingRequestCount)

            GroupsListView()
                .tabItem {
                    Image(systemName: "circle.grid.2x2")
                    Text("Blends")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                        .accessibilityIdentifier("profile.tab")
                }
                .tag(3)
        }
        .tint(.white)
        .environment(tabState)
        .task {
            await tabState.refreshPendingCount()
        }
        .onChange(of: tabState.selectedTab) { _, tab in
            if tab == 1 {
                Task {
                    await tabState.refreshPendingCount()
                }
            }
        }
        .onChange(of: deepLinkState.pending) { _, newValue in
            guard let link = newValue else { return }
            switch link {
            case .friendRequests:
                tabState.selectedTab = 3
            case .groupDetail:
                tabState.selectedTab = 2
            case .movieDetail, .comments:
                tabState.selectedTab = 0
            }
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
