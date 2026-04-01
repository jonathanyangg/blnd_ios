import Foundation

/// Normalized movie struct for the reels feed, unifying all movie response types
struct ReelMovie: Identifiable, Equatable {
    let tmdbId: Int
    let title: String
    let yearString: String
    let posterPath: String?
    let overview: String?
    let scorePercent: Int?
    let genres: [Genre]
    let trailerUrl: String?
    let backdropPath: String?
    let runtime: Int?
    let voteAverage: Double?
    let director: String?
    let cast: [CastMember]
    let tagline: String?

    var id: Int {
        tmdbId
    }

    var runtimeFormatted: String? {
        guard let runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static func == (lhs: ReelMovie, rhs: ReelMovie) -> Bool {
        lhs.tmdbId == rhs.tmdbId
    }

    init(from movie: RecommendedMovieResponse) {
        tmdbId = movie.tmdbId
        title = movie.title
        yearString = movie.yearString
        posterPath = movie.posterPath
        overview = movie.overview
        scorePercent = movie.scorePercent
        genres = movie.genres
        trailerUrl = movie.trailerUrl
        backdropPath = movie.backdropPath
        runtime = movie.runtime
        voteAverage = movie.voteAverage
        director = movie.director
        cast = movie.cast
        tagline = movie.tagline
    }

    init(from movie: MovieResponse) {
        tmdbId = movie.tmdbId
        title = movie.title
        yearString = movie.yearString
        posterPath = movie.posterPath
        overview = movie.overview
        scorePercent = movie.matchPercent
        genres = movie.genres
        trailerUrl = movie.trailerUrl
        backdropPath = movie.backdropPath
        runtime = movie.runtime
        voteAverage = movie.voteAverage
        director = movie.director
        cast = movie.cast
        tagline = movie.tagline
    }

    init(from movie: GroupRecMovieResponse) {
        tmdbId = movie.tmdbId
        title = movie.title
        yearString = movie.yearString
        posterPath = movie.posterPath
        overview = movie.overview
        scorePercent = movie.scorePercent
        genres = movie.genres
        trailerUrl = movie.trailerUrl
        backdropPath = movie.backdropPath
        runtime = movie.runtime
        voteAverage = movie.voteAverage
        director = movie.director
        cast = movie.cast
        tagline = movie.tagline
    }

    init(from movie: WatchlistMovieResponse) {
        tmdbId = movie.tmdbId
        title = movie.title
        yearString = movie.yearString
        posterPath = movie.posterPath
        overview = movie.overview
        scorePercent = movie.matchPercent
        genres = movie.genres
        trailerUrl = movie.trailerUrl
        backdropPath = movie.backdropPath
        runtime = movie.runtime
        voteAverage = movie.voteAverage
        director = movie.director
        cast = movie.cast
        tagline = movie.tagline
    }
}
