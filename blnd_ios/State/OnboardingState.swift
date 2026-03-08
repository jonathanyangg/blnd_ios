import Foundation

struct RatedMovie {
    let tmdbId: Int
    let title: String
    let year: Int?
    let posterPath: String?
    let liked: Bool
}

/// Caches onboarding data so navigating back preserves state.
@Observable
class OnboardingState {
    var name = ""
    var username = ""
    var email = ""
    var password = ""

    var selectedGenres: Set<String> = []
    var movieRatings: [Int: Bool] = [:]
    var ratedMovies: [RatedMovie] = []

    var likedMovies: [RatedMovie] {
        ratedMovies.filter(\.liked)
    }

    func reset() {
        name = ""
        username = ""
        email = ""
        password = ""
        selectedGenres = []
        movieRatings = [:]
        ratedMovies = []
    }
}
