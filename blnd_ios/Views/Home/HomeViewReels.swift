import SwiftUI

// MARK: - Reels Mode

extension HomeView {
    var reelsContent: some View {
        ZStack(alignment: .top) {
            switch selectedTab {
            case .forYou:
                if isLoadingFYP {
                    ProgressView()
                        .tint(.white)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                } else if let error = fypError {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadForYou() }
                        }
                        .font(.system(
                            size: 14,
                            weight: .semibold
                        ))
                        .foregroundStyle(.white)
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                } else {
                    ReelsFeedView(
                        movies: recommendations.map {
                            ReelMovie(from: $0)
                        },
                        onRefresh: {
                            await refreshFYP()
                        }
                    )
                }
            case .discover:
                DiscoverSectionView(
                    cardWidth: 0,
                    cardHeight: 0,
                    viewMode: .reels
                )
            }

            reelsOverlayHeader
        }
        .task { await loadForYou() }
    }

    var reelsOverlayHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("blnd")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
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
            .padding(.top, 60)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

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
                                        : .white.opacity(0.6)
                                )
                                .shadow(radius: 2)

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
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [
                    .black.opacity(0.6),
                    .black.opacity(0.3),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(true)
    }
}
