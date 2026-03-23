import SwiftUI

// MARK: - Grid Mode

extension HomeView {
    var gridContent: some View {
        GeometryReader { geo in
            let cardWidth = (geo.size.width - 24 * 2 - 12) / 2
            let cardHeight = cardWidth * 1.5

            ScrollView {
                VStack(spacing: 0) {
                    gridHeader
                    gridTabPicker()
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
                            cardHeight: cardHeight,
                            viewMode: .grid
                        )
                    }
                }
                .padding(.bottom, 16)
            }
            .background(AppTheme.background)
            .refreshable { await refreshCurrentTab() }
            .task { await loadForYou() }
        }
    }

    var gridHeader: some View {
        HStack {
            Text("blnd")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = .reels
                    }
                } label: {
                    Image(systemName: "rectangle.stack")
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
        .padding(.top, 16)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    func forYouContent(
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
                movieGrid(
                    cardWidth: cardWidth,
                    cardHeight: cardHeight
                )
            }
        }
    }

    func movieGrid(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(
                Array(recommendations.enumerated()),
                id: \.element.id
            ) { index, movie in
                fypGridCard(
                    movie: movie, index: index,
                    cardWidth: cardWidth, cardHeight: cardHeight
                )
            }

            if isLoadingMoreFYP {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 24)
    }

    private func fypGridCard(
        movie: RecommendedMovieResponse,
        index: Int,
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        NavigationLink {
            MovieDetailView(
                tmdbId: movie.tmdbId,
                title: movie.title,
                onHide: {
                    withAnimation {
                        recommendations.removeAll {
                            $0.tmdbId == movie.tmdbId
                        }
                    }
                }
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
        .onAppear {
            if index >= recommendations.count - 4 {
                Task { await loadMoreFYP() }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                hideMovie(movie.tmdbId)
            } label: {
                Label(
                    "Not for me",
                    systemImage: "hand.thumbsdown"
                )
            }
        }
    }

    var loadingView: some View {
        ProgressView()
            .tint(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    func errorView(
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
}
