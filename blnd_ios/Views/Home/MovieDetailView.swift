import SwiftUI

struct MovieDetailView: View {
    let tmdbId: Int
    var title: String = ""

    @State private var movie: MovieResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showRatingSheet = false
    @State private var isInWatchlist = false

    private var displayTitle: String {
        movie?.title ?? title
    }

    private var displayYear: String {
        movie?.yearString ?? ""
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await fetchMovie() }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else if let movie {
                movieContent(movie)
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .sheet(isPresented: $showRatingSheet) {
            RateMovieSheet(title: displayTitle, year: displayYear)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.card)
        }
        .task {
            await fetchMovie()
        }
    }

    // MARK: - Movie Content

    private func movieContent(_ movie: MovieResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            heroSection(movie)
            detailSection(movie)
        }
        .padding(.bottom, 32)
    }

    private func heroSection(_ movie: MovieResponse) -> some View {
        ZStack {
            if let backdrop = movie.backdropPath {
                AsyncImage(
                    url: URL(string: "https://image.tmdb.org/t/p/w780\(backdrop)")
                ) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }

            if movie.trailerUrl != nil {
                Image(systemName: "play.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 24)
    }

    private func detailSection(_ movie: MovieResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(movie.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 16)

            metaRow(movie)
            genreRow(movie)
            ratingSection(movie)
            overviewSection(movie)
            actionButtons
            castSection(movie)
        }
        .padding(.horizontal, 24)
    }

    private func metaRow(_ movie: MovieResponse) -> some View {
        let meta = [movie.yearString, movie.runtimeFormatted]
            .compactMap { $0?.isEmpty == true ? nil : $0 }
            .joined(separator: " \u{00B7} ")
        return Group {
            if !meta.isEmpty {
                Text(meta)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
            }
        }
    }

    @ViewBuilder
    private func genreRow(_ movie: MovieResponse) -> some View {
        if !movie.genres.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(movie.genres) { genre in
                        GenrePill(label: genre.name, isSmall: true)
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func ratingSection(_ movie: MovieResponse) -> some View {
        if let vote = movie.voteAverage, vote > 0 {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                Text(String(format: "%.1f", vote))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 8)
        }

        HStack(spacing: 2) {
            ForEach(0 ..< 5, id: \.self) { _ in
                Image(systemName: "star")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textDim)
            }
        }
        .padding(.bottom, 8)
        .onTapGesture {
            showRatingSheet = true
        }

        if let tagline = movie.tagline, !tagline.isEmpty {
            Text(tagline)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .italic()
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func overviewSection(_ movie: MovieResponse) -> some View {
        if let overview = movie.overview, !overview.isEmpty {
            Text(overview)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .lineSpacing(4)
                .padding(.bottom, 16)
        }

        if let director = movie.director {
            HStack(spacing: 4) {
                Text("Directed by")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textDim)
                Text(director)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 16)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                showRatingSheet = true
            } label: {
                Text("Watched")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(AppTheme.card)
                    .foregroundStyle(.white)
                    .clipShape(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    )
            }

            Button {
                isInWatchlist.toggle()
            } label: {
                Text(isInWatchlist ? "In Watchlist" : "+ Watchlist")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(isInWatchlist ? AppTheme.card : .white)
                    .foregroundStyle(isInWatchlist ? .white : .black)
                    .clipShape(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    )
            }
        }
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func castSection(_ movie: MovieResponse) -> some View {
        if !movie.cast.isEmpty {
            Text("Cast")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(movie.cast) { member in
                        VStack(spacing: 4) {
                            castAvatar(member)
                            Text(member.name)
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .frame(width: 48)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var heroPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(AppTheme.posterGradient)
            .frame(height: 200)
    }

    @ViewBuilder
    private func castAvatar(_ member: CastMember) -> some View {
        if let path = member.profilePath, let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                default:
                    AvatarView(size: 48)
                }
            }
        } else {
            AvatarView(size: 48)
        }
    }

    private func fetchMovie() async {
        isLoading = true
        errorMessage = nil
        do {
            movie = try await MoviesAPI.getMovie(tmdbId: tmdbId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(tmdbId: 550, title: "Fight Club")
    }
}
