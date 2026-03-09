import SwiftUI

private enum HomeTab: String, CaseIterable {
    case forYou = "For You"
    case discover = "Discover"
}

struct HomeView: View {
    @State private var selectedTab: HomeTab = .forYou
    @State private var showSearch = false
    @Namespace private var tabNamespace

    // For You
    @State private var recommendations: [RecommendedMovieResponse] = []
    @State private var isLoadingFYP = false
    @State private var fypError: String?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let cardWidth = (geo.size.width - 24 * 2 - 12) / 2
                let cardHeight = cardWidth * 1.5

                ScrollView {
                    VStack(spacing: 0) {
                        header
                        tabPicker
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)

                        switch selectedTab {
                        case .forYou:
                            forYouContent(
                                cardWidth: cardWidth,
                                cardHeight: cardHeight
                            )
                        case .discover:
                            DiscoverSectionView(
                                cardWidth: cardWidth,
                                cardHeight: cardHeight
                            )
                        }
                    }
                    .padding(.bottom, 16)
                }
                .background(AppTheme.background)
                .refreshable { await refreshCurrentTab() }
                .task { await loadForYou() }
            }
            .fullScreenCover(isPresented: $showSearch) {
                NavigationStack { SearchView() }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("blnd")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
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
                                    ? .white : AppTheme.textMuted
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

    // MARK: - For You

    private func forYouContent(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        Group {
            if isLoadingFYP {
                loadingView
            } else if let error = fypError {
                errorView(message: error) {
                    Task { await loadForYou() }
                }
            } else {
                movieGrid(cardWidth: cardWidth, cardHeight: cardHeight)
            }
        }
    }

    private func movieGrid(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(recommendations) { movie in
                NavigationLink {
                    MovieDetailView(
                        tmdbId: movie.tmdbId,
                        title: movie.title
                    )
                } label: {
                    MovieCard(
                        title: movie.title,
                        year: movie.yearString,
                        posterPath: movie.posterPath,
                        width: cardWidth,
                        height: cardHeight,
                        scorePercent: movie.scorePercent
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Shared

    private var loadingView: some View {
        ProgressView()
            .tint(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    private func errorView(
        message: String,
        retry: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Retry") { retry() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Data Loading

    private func loadForYou() async {
        guard recommendations.isEmpty else { return }
        isLoadingFYP = true
        fypError = nil
        do {
            let response =
                try await RecommendationsAPI.getRecommendations()
            recommendations = response.results
        } catch {
            if !Task.isCancelled {
                fypError = error.localizedDescription
            }
        }
        isLoadingFYP = false
    }

    @MainActor
    private func refreshCurrentTab() async {
        switch selectedTab {
        case .forYou:
            isLoadingFYP = true
            fypError = nil
            do {
                let resp = try await RecommendationsAPI.refresh()
                recommendations = resp.results
            } catch {
                if !Task.isCancelled {
                    fypError = error.localizedDescription
                }
            }
            isLoadingFYP = false
        case .discover:
            // DiscoverSectionView manages its own state
            break
        }
    }
}

#Preview {
    HomeView()
}
