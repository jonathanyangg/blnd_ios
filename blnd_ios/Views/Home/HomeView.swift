import SwiftUI

private enum HomeTab: String, CaseIterable {
    case forYou = "For You"
    case trending = "Trending"
}

struct HomeView: View {
    @State private var selectedTab: HomeTab = .forYou
    @State private var showSearch = false
    @Namespace private var tabNamespace

    // For You
    @State private var recommendations: [RecommendedMovieResponse] = []
    @State private var isLoadingFYP = false
    @State private var fypError: String?

    // Trending
    @State private var trendingMovies: [MovieResponse] = []
    @State private var isLoadingTrending = false
    @State private var trendingError: String?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        HStack {
                            Text("blnd")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                showSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                        tabPicker
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)

                        let cardWidth = (geo.size.width - 24 * 2 - 12) / 2
                        let cardHeight = cardWidth * 1.5

                        switch selectedTab {
                        case .forYou:
                            forYouContent(cardWidth: cardWidth, cardHeight: cardHeight)
                        case .trending:
                            trendingContent(cardWidth: cardWidth, cardHeight: cardHeight)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .background(AppTheme.background)
                .refreshable {
                    await refreshCurrentTab()
                }
                .task {
                    await loadForYou()
                }
            }
            .fullScreenCover(isPresented: $showSearch) {
                NavigationStack {
                    SearchView()
                }
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 24) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    if tab == .trending, trendingMovies.isEmpty, trendingError == nil {
                        Task { await loadTrending() }
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(
                                size: 15,
                                weight: selectedTab == tab ? .bold : .medium
                            ))
                            .foregroundStyle(
                                selectedTab == tab ? .white : AppTheme.textMuted
                            )

                        if selectedTab == tab {
                            Rectangle()
                                .fill(.white)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "underline", in: tabNamespace)
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

    private func forYouContent(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        Group {
            if isLoadingFYP {
                loadingView
            } else if let error = fypError {
                errorView(message: error) {
                    Task { await loadForYou() }
                }
            } else {
                movieGrid {
                    ForEach(recommendations) { movie in
                        NavigationLink {
                            MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
                        } label: {
                            MovieCard(
                                title: movie.title,
                                year: movie.yearString,
                                posterPath: movie.posterPath,
                                width: cardWidth,
                                height: cardHeight
                            )
                            .overlay(alignment: .topTrailing) {
                                Text("\(movie.similarityPercent)%")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.black.opacity(0.7))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.white)
                                    .padding(6)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Trending

    private func trendingContent(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        Group {
            if isLoadingTrending {
                loadingView
            } else if let error = trendingError {
                errorView(message: error) {
                    Task { await loadTrending() }
                }
            } else {
                movieGrid {
                    ForEach(Array(trendingMovies.enumerated()), id: \.element.id) { index, movie in
                        NavigationLink {
                            MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
                        } label: {
                            MovieCard(
                                title: movie.title,
                                year: movie.yearString,
                                posterPath: movie.posterPath,
                                width: cardWidth,
                                height: cardHeight
                            )
                            .overlay(alignment: .topLeading) {
                                Text("#\(index + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.black.opacity(0.7))
                                    .clipShape(Capsule())
                                    .padding(6)
                            }
                            .overlay(alignment: .topTrailing) {
                                if let pct = movie.matchPercent {
                                    Text("\(pct)%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.black.opacity(0.7))
                                        .clipShape(Capsule())
                                        .padding(6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Shared Components

    private func movieGrid(@ViewBuilder content: () -> some View) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            content()
        }
        .padding(.horizontal, 24)
    }

    private var loadingView: some View {
        ProgressView()
            .tint(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    private func errorView(message: String, retry: @escaping () -> Void) -> some View {
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
            let response = try await RecommendationsAPI.getRecommendations()
            recommendations = response.results
        } catch {
            if !Task.isCancelled {
                fypError = error.localizedDescription
            }
        }
        isLoadingFYP = false
    }

    private func loadTrending() async {
        guard trendingMovies.isEmpty else { return }
        isLoadingTrending = true
        trendingError = nil
        do {
            let response = try await MoviesAPI.trending()
            trendingMovies = response.results
        } catch {
            if !Task.isCancelled {
                trendingError = error.localizedDescription
            }
        }
        isLoadingTrending = false
    }

    @MainActor
    private func refreshCurrentTab() async {
        switch selectedTab {
        case .forYou:
            isLoadingFYP = true
            fypError = nil
            do {
                let response = try await RecommendationsAPI.refresh()
                recommendations = response.results
            } catch {
                if !Task.isCancelled {
                    fypError = error.localizedDescription
                }
            }
            isLoadingFYP = false
        case .trending:
            trendingMovies = []
            trendingError = nil
            await loadTrending()
        }
    }
}

#Preview {
    HomeView()
}
