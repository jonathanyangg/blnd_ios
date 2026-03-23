import SwiftUI

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
    @State var isLoadingFYP = false
    @State var fypError: String?
    @State var toastMessage: String?

    /// Whether to show the first-time scroll hint overlay
    @State private var showScrollHint = !UserDefaults.standard.bool(forKey: "hasScrolledForYou")

    var body: some View {
        NavigationStack {
            ZStack {
                if viewMode == .reels {
                    reelsContent
                } else {
                    gridContent
                }
            }
            .background(AppTheme.background)
            .fullScreenCover(isPresented: $showSearch) {
                NavigationStack { SearchView() }
            }
            .overlay {
                if showScrollHint, selectedTab == .forYou, !recommendations.isEmpty {
                    ScrollHintOverlay {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showScrollHint = false
                        }
                        UserDefaults.standard.set(true, forKey: "hasScrolledForYou")
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

    // MARK: - Grid Mode Tab Picker

    func gridTabPicker() -> some View {
        HStack(spacing: 24) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
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

                        if selectedTab == tab {
                            Rectangle()
                                .fill(.white)
                                .frame(height: 2)
                                .matchedGeometryEffect(
                                    id: "underline",
                                    in: tabNamespace
                                )
                        } else {
                            Rectangle()
                                .fill(.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeView()
}
