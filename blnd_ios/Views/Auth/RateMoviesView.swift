import SwiftUI

struct RateMoviesView: View {
    @Environment(OnboardingState.self) var onboardingState
    @Binding var path: NavigationPath
    @State private var movies: [MovieResponse] = []
    @State private var currentIndex = 0
    @State private var offset: CGSize = .zero
    @State private var isLoading = true

    private let movieCount = 7

    private var currentMovie: MovieResponse? {
        guard currentIndex < movies.count else { return nil }
        return movies[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(step: 2, total: 4)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 0) {
                Text("Rate these")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 32)

                Text("Swipe right to like, left to dislike")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 4)
                    .padding(.bottom, 24)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if movies.isEmpty {
                    Spacer()
                    Text("No movies found")
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    // Card stack
                    ZStack {
                        // Background card
                        if currentIndex + 1 < movies.count {
                            let next = movies[currentIndex + 1]
                            SwipeCard(
                                title: next.title,
                                year: next.year.map { String($0) } ?? "",
                                posterPath: next.posterPath
                            )
                            .scaleEffect(0.9)
                            .rotationEffect(.degrees(-4))
                            .opacity(0.4)
                        }

                        // Front card
                        if let movie = currentMovie {
                            SwipeCard(
                                title: movie.title,
                                year: movie.year.map { String($0) } ?? "",
                                posterPath: movie.posterPath
                            )
                            .offset(offset)
                            .rotationEffect(.degrees(Double(offset.width) * 0.04))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = value.translation
                                    }
                                    .onEnded { value in
                                        if abs(value.translation.width) > 100 {
                                            swipe(liked: value.translation.width > 0)
                                        } else {
                                            withAnimation(.spring(response: 0.3)) {
                                                offset = .zero
                                            }
                                        }
                                    }
                            )
                        }
                    }
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)

                    // Action buttons
                    HStack {
                        Button {
                            swipe(liked: false)
                        } label: {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.system(size: 22))
                                .frame(width: 52, height: 52)
                                .background(AppTheme.card)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                        }

                        Spacer()

                        GenrePill(label: "Haven't seen", isSmall: true) {
                            skip()
                        }

                        Spacer()

                        Button {
                            swipe(liked: true)
                        } label: {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 22))
                                .frame(width: 52, height: 52)
                                .background(AppTheme.card)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 16)

                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(0 ..< movies.count, id: \.self) { index in
                            Circle()
                                .fill(index <= currentIndex ? .white : AppTheme.border)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }

                Spacer()
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
        .task { await fetchMovies() }
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
        } catch {
            print("[RateMoviesView] Discover failed: \(error)")
        }
        isLoading = false
    }

    private func swipe(liked: Bool) {
        guard let movie = currentMovie else { return }
        onboardingState.movieRatings[movie.tmdbId] = liked
        onboardingState.ratedMovies.append(RatedMovie(
            tmdbId: movie.tmdbId,
            title: movie.title,
            year: movie.year,
            posterPath: movie.posterPath,
            liked: liked
        ))
        withAnimation(.easeOut(duration: 0.3)) {
            offset = CGSize(width: liked ? 300 : -300, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            advance()
        }
    }

    private func skip() {
        advance()
    }

    private func advance() {
        offset = .zero
        if currentIndex < movies.count - 1 {
            currentIndex += 1
        } else {
            path.append(AuthRoute.createAccount)
        }
    }
}

// MARK: - Swipe Card

private struct SwipeCard: View {
    let title: String
    let year: String
    let posterPath: String?

    private var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let url = posterURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                        .posterBlur()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.posterGradient)
                }
                .frame(width: 190, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.5), radius: 30, y: 20)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.posterGradient)
                    .frame(width: 190, height: 280)
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 20)
            }

            VStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(year)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16
                )
            )
            .frame(width: 190)
        }
    }
}

#Preview {
    NavigationStack {
        RateMoviesView(path: .constant(NavigationPath()))
            .environment(OnboardingState())
    }
}
