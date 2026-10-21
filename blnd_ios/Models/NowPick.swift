import Foundation

/// `GET /recommendations/now` — one movie and a short reason.
struct NowPickResponse: Decodable {
    let movie: RecommendedMovieResponse
    let reason: String
}

enum NowPickQuery {
    /// Builds the path and query for `GET /recommendations/now`.
    /// `exclude` stays comma-separated so the backend can split tmdb ids.
    static func endpoint(genre: String?, exclude: [Int]) -> String {
        var parts: [String] = []
        let trimmed = genre?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            let encoded = trimmed.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) ?? trimmed
            parts.append("genre=\(encoded)")
        }
        if !exclude.isEmpty {
            let ids = exclude.map(String.init).joined(separator: ",")
            parts.append("exclude=\(ids)")
        }
        guard !parts.isEmpty else { return "/recommendations/now" }
        return "/recommendations/now?\(parts.joined(separator: "&"))"
    }
}

/// Poster grid and screenshot stand-in for `/recommendations/now`.
/// The live app calls the API. This catalog is used when that route is
/// absent (the endpoint ships in blnd_backend#10) and for UI previews.
enum NowCatalog {
    static let movies: [RecommendedMovieResponse] = [
        movie(27205, "Inception", 2010, "/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg", 878, "Science Fiction", 148, "Christopher Nolan", 0.94),
        movie(157336, "Interstellar", 2014, "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg", 878, "Science Fiction", 169, "Christopher Nolan", 0.91),
        movie(155, "The Dark Knight", 2008, "/qJ2tW6WMUDux911r6m7haRef0WH.jpg", 28, "Action", 152, "Christopher Nolan", 0.88),
        movie(680, "Pulp Fiction", 1994, "/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg", 80, "Crime", 154, "Quentin Tarantino", 0.86),
        movie(238, "The Godfather", 1972, "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg", 18, "Drama", 175, "Francis Ford Coppola", 0.9),
        movie(496243, "Parasite", 2019, "/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg", 53, "Thriller", 132, "Bong Joon Ho", 0.93),
        movie(244786, "Whiplash", 2014, "/7fn624j5lj3xTme2SgiLCeuedmO.jpg", 18, "Drama", 107, "Damien Chazelle", 0.89),
        movie(313369, "La La Land", 2016, "/uDO8zWDhfWwoFdKS4fzkUJt0Rf0.jpg", 10749, "Romance", 128, "Damien Chazelle", 0.84),
        movie(335984, "Blade Runner 2049", 2017, "/gajva2L0rPYkEWjzgFlBXCAVBE5.jpg", 878, "Science Fiction", 164, "Denis Villeneuve", 0.87),
        movie(438631, "Dune", 2021, "/d5NXSklXo0qyIYkgV94XAgMIckC.jpg", 878, "Science Fiction", 155, "Denis Villeneuve", 0.92),
        movie(129, "Spirited Away", 2001, "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg", 16, "Animation", 125, "Hayao Miyazaki", 0.9),
        movie(603, "The Matrix", 1999, "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg", 878, "Science Fiction", 136, "Lana Wachowski", 0.85),
        movie(120467, "The Grand Budapest Hotel", 2014, "/eWdyYQreja6JGCzqHWXpWHDrrPo.jpg", 35, "Comedy", 99, "Wes Anderson", 0.83),
        movie(545611, "Everything Everywhere All at Once", 2022, "/w3LxiVYdWWRvEVdn5RYq6jIqkb1.jpg", 878, "Science Fiction", 139, "Daniel Kwan", 0.91),
        movie(10681, "WALL·E", 2008, "/hbhFnRzzg6ZDmm8YAmxBnQpQIPh.jpg", 16, "Animation", 98, "Andrew Stanton", 0.86),
        movie(419430, "Get Out", 2017, "/tFXcEccSQMf3lfhfXKSU9iRBpa3.jpg", 27, "Horror", 104, "Jordan Peele", 0.88),
        movie(376867, "Moonlight", 2016, "/4911T5FbJ9eD2Faz5Z8cT3SUhU3.jpg", 18, "Drama", 111, "Barry Jenkins", 0.9),
        movie(550, "Fight Club", 1999, "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg", 18, "Drama", 139, "David Fincher", 0.8),
    ]

    static var feed: [RecommendedMovieResponse] {
        Array(movies.prefix(8))
    }

    /// Next catalog title, skipping ids the user already saw.
    /// Still returns a movie when every id is excluded.
    static func pick(
        excluding: [Int],
        lovedTitles: [String] = []
    ) -> NowPickResponse {
        let movie = movies.first { !excluding.contains($0.tmdbId) } ?? movies[0]
        return NowPickResponse(movie: movie, reason: reason(excluding: excluding, lovedTitles: lovedTitles))
    }

    private static func reason(excluding: [Int], lovedTitles: [String]) -> String {
        if let loved = lovedTitles.first {
            return "Because you rated \(loved) highly"
        }
        if excluding.isEmpty {
            return "Popular right now"
        }
        return "Because it matches your taste"
    }

    private static func movie(
        _ tmdbId: Int,
        _ title: String,
        _ year: Int,
        _ posterPath: String,
        _ genreId: Int,
        _ genre: String,
        _ runtime: Int,
        _ director: String,
        _ matchScore: Double
    ) -> RecommendedMovieResponse {
        RecommendedMovieResponse(
            tmdbId: tmdbId,
            mediaType: .movie,
            title: title,
            year: year,
            overview: nil,
            posterPath: posterPath,
            genres: [Genre(id: genreId, name: genre)],
            runtime: runtime,
            voteAverage: 4.2,
            trailerUrl: nil,
            director: director,
            cast: [],
            tagline: nil,
            backdropPath: nil,
            matchScore: matchScore,
            commentCount: 0
        )
    }
}
