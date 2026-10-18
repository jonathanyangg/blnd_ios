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
    @State var fypError: String?
    @State var fypCurrentId: Int?
    @State var discoverCurrentId: Int?
    @State var toastMessage: String?
    @State var toastTask: Task<Void, Never>?
    @State var showStickySearch = false
    @State var lastScrollOffset: CGFloat = 0
    @State var deepLinkTmdbId: Int?

    /// Show tutorial overlay on first launch only
    @AppStorage("hasSeenReelsTutorial") private var hasSeenTutorial = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                homeHeader
                if viewMode == .reels {
                    reelsFeed
                        .task { await loadForYou() }
                        .allowsHitTesting(hasSeenTutorial || isLoadingFYP || fypReelMovies.isEmpty)
                } else {
                    gridFeed
                        .task { await loadForYou() }
                }
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
            .overlay {
                if !hasSeenTutorial, viewMode == .reels, !isLoadingFYP, !fypReelMovies.isEmpty {
                    ScrollHintOverlay {
                        hasSeenTutorial = true
                    }
                }
            }
            .onChange(of: tabState.homeRefreshTrigger) {
                Task { await refreshFYP() }
            }
            .navigationDestination(item: $deepLinkTmdbId) { tmdbId in
                MovieDetailView(tmdbId: tmdbId, source: .notification)
            }
            .onChange(of: deepLinkState.pending) { _, newValue in
                if case let .movieDetail(tmdbId) = newValue {
                    deepLinkTmdbId = tmdbId
                    deepLinkState.pending = nil
                }
            }
            .onAppear {
                if case let .movieDetail(tmdbId) = deepLinkState.pending {
                    deepLinkTmdbId = tmdbId
                    deepLinkState.pending = nil
                }
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
                Button {
                    Task { await refreshCurrentTab() }
                } label: {
                    Text("blnd")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                HStack(spacing: 16) {
                    if !authState.isPremium {
                        Button { showPaywall = true } label: {
                            Text("+")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.premiumGoldGradient)
                        }
                        .accessibilityIdentifier("home.paywall")
                    }
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
                    .accessibilityIdentifier("home.search")
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

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
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

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
                        Analytics.tabSwitched(tab: tab.rawValue)
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
