import SwiftUI

struct ActorProfileView: View {
    let personId: Int
    let name: String
    let profilePath: String?

    @State private var movies: [MovieResponse] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var seenIds: Set<Int> = []
    @State private var isLiked = false
    @State private var isLikeLoading = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                actorHeader
                Divider().overlay(AppTheme.border)
                filmographyGrid
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .task {
            async let loadFilm: () = loadFilmography()
            async let checkLike: () = checkLikedStatus()
            _ = await (loadFilm, checkLike)
        }
    }

    // MARK: - Header

    private var actorHeader: some View {
        VStack(spacing: 12) {
            actorAvatar
                .frame(width: 80, height: 80)
                .clipShape(Circle())

            Text(name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            likeButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var actorAvatar: some View {
        let base = "https://image.tmdb.org/t/p/w185"
        if let path = profilePath, let url = URL(string: "\(base)\(path)") {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .posterBlur()
            } placeholder: {
                avatarPlaceholder
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(AppTheme.card)
            Image(systemName: "person.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.textDim)
        }
    }

    private var likeButton: some View {
        Button {
            Task { await toggleLike() }
        } label: {
            HStack(spacing: 6) {
                if isLikeLoading {
                    ProgressView()
                        .tint(isLiked ? .black : .white)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 13))
                }
                Text(isLiked ? "Liked" : "Like")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isLiked ? .white : AppTheme.card)
            .foregroundStyle(isLiked ? .black : .white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isLiked ? .clear : AppTheme.border, lineWidth: 1)
            )
        }
        .disabled(isLikeLoading)
    }

    // MARK: - Filmography Grid

    @ViewBuilder
    private var filmographyGrid: some View {
        if isLoading {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if movies.isEmpty {
            VStack(spacing: 8) {
                Text("No movies found")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Text("We couldn't find any movies for this actor")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(
                    Array(movies.enumerated()),
                    id: \.element.id
                ) { index, movie in
                    NavigationLink {
                        MovieDetailView(
                            tmdbId: movie.tmdbId,
                            title: movie.title,
                            source: .search
                        )
                    } label: {
                        MovieCard(
                            tmdbId: movie.tmdbId,
                            title: movie.title,
                            year: movie.yearString,
                            posterPath: movie.posterPath,
                            width: cardWidth,
                            height: cardHeight,
                            scorePercent: movie.matchPercent
                        )
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if index == movies.count - 4 {
                            Task { await loadNextPage() }
                        }
                    }
                }

                if isLoadingMore {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }

    private var cardWidth: CGFloat {
        (UIScreen.main.bounds.width - 24 * 2 - 12) / 2
    }

    private var cardHeight: CGFloat {
        cardWidth * 1.5
    }

    // MARK: - Data

    private func loadFilmography() async {
        isLoading = true
        do {
            let response = try await MoviesAPI.getPersonCredits(personId: personId)
            movies = response.results
            seenIds = Set(response.results.map(\.tmdbId))
            hasMorePages = !response.results.isEmpty
        } catch {
            print("[ActorProfile] Error loading filmography: \(error)")
        }
        isLoading = false
    }

    private func loadNextPage() async {
        guard hasMorePages, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let response = try await MoviesAPI.getPersonCredits(
                personId: personId,
                exclude: seenIds
            )
            let newMovies = response.results.filter { !seenIds.contains($0.tmdbId) }
            if newMovies.isEmpty {
                hasMorePages = false
            } else {
                movies.append(contentsOf: newMovies)
                for movie in newMovies {
                    seenIds.insert(movie.tmdbId)
                }
            }
        } catch {
            hasMorePages = false
        }
        isLoadingMore = false
    }

    private func checkLikedStatus() async {
        do {
            let response = try await ActorsAPI.getLikedActors()
            isLiked = response.results.contains { $0.tmdbPersonId == personId }
        } catch {
            print("[ActorProfile] Error checking liked status: \(error)")
        }
    }

    private func toggleLike() async {
        isLikeLoading = true
        do {
            if isLiked {
                try await ActorsAPI.unlikeActor(personId: personId)
                isLiked = false
            } else {
                _ = try await ActorsAPI.likeActor(
                    personId: personId,
                    name: name,
                    profilePath: profilePath
                )
                isLiked = true
            }
        } catch {
            print("[ActorProfile] Error toggling like: \(error)")
        }
        isLikeLoading = false
    }
}
