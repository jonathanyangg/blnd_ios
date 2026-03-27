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

    var id: Int {
        tmdbId
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
        backdropPath = nil
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
    }

    init(from movie: GroupRecMovieResponse) {
        tmdbId = movie.tmdbId
        title = movie.title
        yearString = movie.yearString
        posterPath = movie.posterPath
        overview = movie.overview
        scorePercent = movie.scorePercent
        genres = []
        trailerUrl = movie.trailerUrl
        backdropPath = nil
    }

    init(from movie: WatchlistMovieResponse) {
        tmdbId = movie.tmdbId
        title = movie.title
        yearString = ""
        posterPath = movie.posterPath
        overview = nil
        scorePercent = movie.matchPercent
        genres = []
        trailerUrl = movie.trailerUrl
        backdropPath = nil
    }
}
