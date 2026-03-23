import SwiftUI

// MARK: - Reels Mode

extension HomeView {
    var reelsContent: some View {
        VStack(spacing: 0) {
            reelsHeader
            reelsFeed
        }
        .task { await loadForYou() }
    }

    private var reelsHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("blnd")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = .grid
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2")
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
            .padding(.horizontal, 24)
            .padding(.bottom, 4)

            Divider()
                .overlay(AppTheme.border)
        }
        .background(AppTheme.background)
    }

    @ViewBuilder
    private var reelsFeed: some View {
        switch selectedTab {
        case .forYou:
            if isLoadingFYP {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if let error = fypError {
                Spacer()
                errorView(message: error) {
                    Task { await loadForYou() }
                }
                Spacer()
            } else {
                ReelsFeedView(
                    movies: recommendations.map {
                        ReelMovie(from: $0)
                    },
                    onRefresh: { await refreshFYP() }
                )
            }
        case .discover:
            DiscoverSectionView(
                cardWidth: 0,
                cardHeight: 0,
                viewMode: .reels
            )
        }
    }
}
