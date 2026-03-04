import SwiftUI

private enum HomeTab: String, CaseIterable {
    case forYou = "For You"
    case trending = "Trending"
}

struct HomeView: View {
    @State private var selectedTab: HomeTab = .forYou

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
                        NavigationLink {
                            SearchView()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(AppTheme.textDim)
                                    .font(.system(size: 15))

                                Text("Search movies...")
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppTheme.textMuted)

                                Spacer()
                            }
                            .padding(14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                        }
                        .buttonStyle(.plain)
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
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    if tab == .trending, trendingMovies.isEmpty, trendingError == nil {
                        Task { await loadTrending() }
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(selectedTab == tab ? .white : AppTheme.card)
                        .foregroundStyle(selectedTab == tab ? .black : AppTheme.textMuted)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
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
        } catch is CancellationError {
            // Ignore task cancellation (e.g. from pull-to-refresh)
        } catch {
            fypError = error.localizedDescription
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
        } catch is CancellationError {
            // Ignore task cancellation
        } catch {
            trendingError = error.localizedDescription
        }
        isLoadingTrending = false
    }

    private func refreshCurrentTab() async {
        switch selectedTab {
        case .forYou:
            recommendations = []
            await loadForYou()
        case .trending:
            trendingMovies = []
            await loadTrending()
        }
    }
}

#Preview {
    HomeView()
}
