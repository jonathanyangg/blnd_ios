import SwiftUI

struct RateMoviesView: View {
    @Environment(OnboardingState.self) var onboardingState
    @Binding var path: NavigationPath
    @State private var movies: [MovieResponse] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var cardOffset: CGFloat = 0
    @State private var cardOpacity: Double = 1
    @State private var dragOffset: CGFloat = 0

    /// Per-card state: rating (0 = unrated) and whether user tapped "Haven't seen"
    @State private var ratings: [Int: Double] = [:]
    @State private var skipped: Set<Int> = []

    private let movieCount = 7

    private var currentMovie: MovieResponse? {
        guard currentIndex < movies.count else { return nil }
        return movies[currentIndex]
    }

    private var currentRating: Double {
        guard let movie = currentMovie else { return 0 }
        return ratings[movie.tmdbId] ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(step: 2, total: 5)
                .padding(.top, 12)

            VStack(spacing: 0) {
                Text("Rate these")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 32)

                Text("Tap stars to rate — half stars work too")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .padding(.bottom, 32)

                if isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if movies.isEmpty {
                    Spacer()
                    Text("No movies found")
                        .foregroundStyle(AppTheme.textMuted)
                    Spacer()
                } else {
                    cardStack
                    Spacer(minLength: 24)
                    ratingSection
                    pageDots
                        .padding(.top, 20)
                    Spacer(minLength: 16)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .task {
            Analytics.onboardingStepViewed(step: .rateMovies)
            await fetchMovies()
        }
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            ForEach(
                Array(visibleCards.enumerated().reversed()),
                id: \.element.tmdbId
            ) { stackIndex, movie in
                let isTop = stackIndex == 0

                MovieCard(
                    tmdbId: movie.tmdbId,
                    title: isTop ? movie.title : "",
                    year: isTop ? (movie.year.map { String($0) } ?? "") : "",
                    posterPath: movie.posterPath,
                    width: 200,
                    height: 300
                )
                .scaleEffect(scale(for: stackIndex))
                .offset(y: yOffset(for: stackIndex))
                .opacity(isTop ? cardOpacity : opacity(for: stackIndex))
                .offset(x: isTop ? dragOffset : 0, y: isTop ? cardOffset : 0)
                .zIndex(Double(visibleCards.count - stackIndex))
            }
        }
        .frame(height: 340)
        .gesture(swipeBackGesture)
    }

    private var visibleCards: [MovieResponse] {
        let remaining = Array(movies.dropFirst(currentIndex))
        return Array(remaining.prefix(3))
    }

    private func scale(for stackIndex: Int) -> CGFloat {
        1.0 - CGFloat(stackIndex) * 0.06
    }

    private func yOffset(for stackIndex: Int) -> CGFloat {
        CGFloat(stackIndex) * 12
    }

    private func opacity(for stackIndex: Int) -> Double {
        1.0 - Double(stackIndex) * 0.2
    }

    // MARK: - Swipe Back Gesture

    private var swipeBackGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                // Only allow right swipe (positive) when there's a previous card
                if value.translation.width > 0, currentIndex > 0 {
                    dragOffset = value.translation.width * 0.5
                }
            }
            .onEnded { value in
                if value.translation.width > 80, currentIndex > 0 {
                    goBack()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(spacing: 16) {
            StarRatingInput(
                rating: Binding(
                    get: { currentRating },
                    set: { newValue in
                        guard let movie = currentMovie else { return }
                        skipped.remove(movie.tmdbId)
                        ratings[movie.tmdbId] = newValue
                        if newValue > 0 {
                            submitAndAdvance(movie: movie)
                        }
                    }
                ),
                starSize: 36,
                spacing: 12
            )

            Button { skipAndAdvance() } label: {
                let isSkipped = currentMovie.map { skipped.contains($0.tmdbId) } ?? false
                Text("Haven't seen")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSkipped ? .black : AppTheme.textMuted)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(isSkipped ? .white : AppTheme.card)
                    .clipShape(Capsule())
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< movies.count, id: \.self) { index in
                Circle()
                    .fill(index <= currentIndex ? .white : AppTheme.border)
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Actions

    private func submitAndAdvance(movie: MovieResponse) {
        let movieRating = ratings[movie.tmdbId] ?? 0
        if movieRating > 0 {
            onboardingState.movieRatings[movie.tmdbId] = movieRating
            // Remove any previous entry for this movie before re-adding
            onboardingState.ratedMovies.removeAll { $0.tmdbId == movie.tmdbId }
            onboardingState.ratedMovies.append(RatedMovie(
                tmdbId: movie.tmdbId,
                title: movie.title,
                year: movie.year,
                posterPath: movie.posterPath,
                rating: movieRating
            ))
        }
        animateForward()
    }

    private func skipAndAdvance() {
        guard let movie = currentMovie else { return }
        skipped.insert(movie.tmdbId)
        ratings.removeValue(forKey: movie.tmdbId)
        onboardingState.movieRatings.removeValue(forKey: movie.tmdbId)
        onboardingState.ratedMovies.removeAll { $0.tmdbId == movie.tmdbId }
        animateForward()
    }

    private func goBack() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = 0
        }
        guard currentIndex > 0 else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            cardOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            currentIndex -= 1
            cardOffset = 0
            cardOpacity = 1
        }
    }

    private func animateForward() {
        withAnimation(.easeOut(duration: 0.25)) {
            cardOffset = -40
            cardOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            cardOffset = 0
            cardOpacity = 1
            dragOffset = 0

            if currentIndex < movies.count - 1 {
                currentIndex += 1
            } else {
                path.append(AuthRoute.createAccount)
            }
        }
    }

    private func fetchMovies() async {
        let genres = Array(onboardingState.selectedGenres)
        guard !genres.isEmpty else {
            isLoading = false
            return
        }
        do {
            let result = try await MoviesAPI.discover(genres: genres)
            movies = Array(result.results.prefix(movieCount))
        } catch { /* Non-critical — empty state shown */ }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        RateMoviesView(path: .constant(NavigationPath()))
            .environment(OnboardingState())
    }
}
