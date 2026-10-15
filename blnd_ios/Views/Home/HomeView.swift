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
    @Environment(TabState.self) var tabState
    @Environment(DeepLinkState.self) var deepLinkState
    @Environment(AuthState.self) var authState
    @State var selectedTab: HomeTab = .forYou
    @State var showSearch = false
    @State var showFindNow = false
    @State var showPaywall = false
    @State var viewMode: ViewMode = UITestLaunch.prefersGrid ? .grid : .reels
    @Namespace private var tabNamespace

    // For You
    @State var recommendations: [RecommendedMovieResponse] = []
    @State var fypReelMovies: [ReelMovie] = []
    @State var seenFYPIds: Set<Int> = []
    @State var isLoadingFYP = false
    @State var isLoadingMoreFYP = false
    @State var fypError: UserFacingError?
    @State var fypCurrentId: Int?
    @State var discoverCurrentId: Int?
    @State var toastMessage: UserFacingError?
    @State var toastRetry: (() -> Void)?
    @State var toastTask: Task<Void, Never>?
    @State var showStickySearch = false
    @State var lastScrollOffset: CGFloat = 0
    @State var deepLinkTmdbId: Int?
    @State var catalogFilters = CatalogFilterStore.shared
    @State var deepLinkCommentsId: Int?

    /// Show the reel coach once. The key matches `ReelTutorialStore`.
    @AppStorage(ReelTutorialStore.seenKey) private var hasSeenTutorial = false
    @State var tutorialNudge = ReelTutorialNudge.rest
    @State var tutorialFrames: [ReelTutorialTarget: CGRect] = [:]

    var showReelTutorial: Bool {
        !hasSeenTutorial
            && viewMode == .reels
            && selectedTab == .forYou
            && !isLoadingFYP
            && !fypReelMovies.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                homeHeader
                if viewMode == .reels {
                    reelsFeed
                        .task { await loadForYou() }
                        .allowsHitTesting(!showReelTutorial)
                        .coordinateSpace(name: "homeReel")
                        .onPreferenceChange(ReelTutorialFrameKey.self) { tutorialFrames = $0 }
                        .overlay {
                            if showReelTutorial {
                                ReelTutorialOverlay(
                                    frames: tutorialFrames,
                                    nudge: $tutorialNudge,
                                    initialIndex: UITestLaunch.tutorialStep,
                                    onDismiss: dismissReelTutorial
                                )
                            }
                        }
                } else {
                    gridFeed
                }
            }
            .task(id: catalogFilters.filter) {
                recommendations = []
                seenFYPIds = []
                fypReelMovies = []
                fypCurrentId = nil
                await loadForYou()
            }
            .background(AppTheme.background)
            .fullScreenCover(isPresented: $showSearch) {
                NavigationStack { SearchView() }
            }
            .fullScreenCover(isPresented: $showFindNow) {
                FindMovieNowView()
            }
            .onChange(of: showSearch) { _, isShowing in
                if isShowing {
                    TrailerPlayer.shared.stop()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(source: .aiSearch)
                    .environment(authState)
            }
            .onChange(of: tabState.homeRefreshTrigger) {
                Task { await refreshFYP() }
            }
            .navigationDestination(item: $deepLinkTmdbId) { tmdbId in
                MovieDetailView(tmdbId: tmdbId, source: .notification)
            }
            .navigationDestination(item: $deepLinkCommentsId) { tmdbId in
                MovieCommentsView(tmdbId: tmdbId, movieTitle: "Comments")
            }
            .onChange(of: deepLinkState.pending) { _, newValue in
                consumeHomeLink(newValue)
            }
            .onAppear {
                consumeHomeLink(deepLinkState.pending)
            }
            .overlay(alignment: .top) {
                if let toast = toastMessage {
                    ErrorToast(message: toast, retry: toastRetry, onDismiss: dismissToast)
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                        .transition(
                            .move(edge: .top)
                                .combined(with: .opacity)
                        )
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
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task { await refreshCurrentTab() }
                } label: {
                    Text("blnd")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityHint("Refreshes this feed")
                Spacer()
                HStack(spacing: 18) {
                    if !authState.isPremium {
                        Button { showPaywall = true } label: {
                            Text("+")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.premiumGoldGradient)
                        }
                        .accessibilityLabel("Blnd Plus")
                    }
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                    Button { showFindNow = true } label: {
                        Image(systemName: "sparkle")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("find-movie-now-button")
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showFindNow = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Find a movie now")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.white)
                .clipShape(Capsule())
            }
            .accessibilityIdentifier("find-movie-now.entry")
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            HStack {
                CatalogFilterButton()
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            homeTabPicker()
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .background(AppTheme.background)
    }

    func dismissReelTutorial() {
        tutorialNudge = .rest
        ReelTutorialStore.markSeen()
        hasSeenTutorial = true
    }

    func homeTabPicker() -> some View {
        HStack(spacing: 24) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    guard selectedTab != tab else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                        Analytics.tabSwitched(tab: tab.rawValue)
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(
                                size: 15,
                                weight: selectedTab == tab
                                    ? .semibold : .medium
                            ))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? .white
                                    : AppTheme.textMuted
                            )

                        ZStack {
                            Capsule()
                                .fill(.clear)
                                .frame(height: 2)
                            if selectedTab == tab {
                                Capsule()
                                    .fill(.white)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(
                                        id: "homeTab",
                                        in: tabNamespace
                                    )
                            }
                        }
                    }
                }
            }
        }
    }

    private func consumeHomeLink(_ link: DeepLink?) {
        switch link {
        case let .movieDetail(tmdbId):
            deepLinkTmdbId = tmdbId
            deepLinkState.pending = nil
        case let .comments(tmdbId):
            deepLinkCommentsId = tmdbId
            deepLinkState.pending = nil
        default:
            break
        }
    }
}

#Preview {
    HomeView()
}
