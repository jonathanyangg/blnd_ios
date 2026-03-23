import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

enum HomeTab: String, CaseIterable {
    case forYou = "For You"
    case discover = "Discover"
}

struct HomeView: View {
    @Environment(TabState.self) private var tabState
    @State var selectedTab: HomeTab = .forYou
    @State var showSearch = false
    @State var viewMode: ViewMode = .reels
    @Namespace private var tabNamespace

    // For You
    @State var recommendations: [RecommendedMovieResponse] = []
    @State var fypReelMovies: [ReelMovie] = []
    @State var seenFYPIds: Set<Int> = []
    @State var isLoadingFYP = false
    @State var isLoadingMoreFYP = false
    @State var fypError: String?
    @State var toastMessage: String?
    @State var showStickySearch = false
    @State var lastScrollOffset: CGFloat = 0

    private static let tutorialKey = "hasSeenReelsTutorial"

    /// Show tutorial overlay on first launch only
    @State private var showTutorial = !UserDefaults.standard.bool(forKey: tutorialKey)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                homeHeader
                if viewMode == .reels {
                    reelsFeed
                        .task { await loadForYou() }
                } else {
                    gridFeed
                        .task { await loadForYou() }
                }
            }
            .background(AppTheme.background)
            .fullScreenCover(isPresented: $showSearch) {
                NavigationStack { SearchView() }
            }
            .overlay {
                if showTutorial, !recommendations.isEmpty {
                    ScrollHintOverlay {
                        showTutorial = false
                        UserDefaults.standard.set(
                            true, forKey: Self.tutorialKey
                        )
                    }
                }
            }
            .onChange(of: tabState.homeRefreshTrigger) {
                Task { await refreshFYP() }
            }
            .overlay(alignment: .top) {
                if let toast = toastMessage {
                    Text(toast)
                        .font(.system(
                            size: 13,
                            weight: .medium
                        ))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.top, 60)
                        .transition(
                            .move(edge: .top)
                                .combined(with: .opacity)
                        )
                        .onTapGesture { dismissToast() }
                }
            }
            .animation(
                .easeInOut(duration: 0.3),
                value: toastMessage
            )
        }
    }

    // MARK: - Shared Header

    var homeHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("blnd")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = viewMode == .reels
                                ? .grid : .reels
                        }
                    } label: {
                        Image(
                            systemName: viewMode == .reels
                                ? "square.grid.2x2"
                                : "rectangle.stack"
                        )
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                    }
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            homeTabPicker()
                .padding(.horizontal, 24)
                .padding(.bottom, 4)

            Divider()
                .overlay(AppTheme.border)
        }
        .background(AppTheme.background)
    }

    func homeTabPicker() -> some View {
        HStack(spacing: 24) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(
                                size: 15,
                                weight: selectedTab == tab
                                    ? .bold : .medium
                            ))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? .white
                                    : AppTheme.textMuted
                            )

                        Rectangle()
                            .fill(
                                selectedTab == tab
                                    ? .white : .clear
                            )
                            .frame(height: 2)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
