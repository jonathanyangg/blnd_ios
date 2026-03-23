import SwiftUI

struct MainTabView: View {
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

            FriendsListView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Friends")
                }
                .tag(1)

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
                }
                .tag(3)
        }
        .tint(.white)
        .environment(tabState)
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
