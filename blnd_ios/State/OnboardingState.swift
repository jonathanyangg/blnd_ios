import Foundation

struct RatedMovie {
    let tmdbId: Int
    let title: String
    let year: Int?
    let posterPath: String?
    let rating: Double
}

/// Caches onboarding data so navigating back preserves state.
@Observable
class OnboardingState {
    var name = ""
    var username = ""
    var email = ""
    var password = ""

    var phoneNumber = ""

    var selectedGenres: Set<String> = []
    var movieRatings: [Int: Double] = [:]
    var ratedMovies: [RatedMovie] = []

    // Apple Sign In fields
    var appleIdToken: String?
    var appleRawNonce: String?
    var appleDisplayName: String?
    var appleAuthCode: String?
    var appleRefreshToken: String?

    var isAppleSignUp: Bool {
        appleIdToken != nil
    }

    var likedMovies: [RatedMovie] {
        ratedMovies.filter { $0.rating >= 3.0 }
    }

    func reset() {
        name = ""
        username = ""
        email = ""
        password = ""
        phoneNumber = ""
        selectedGenres = []
        movieRatings = [:]
        ratedMovies = []
        appleIdToken = nil
        appleRawNonce = nil
        appleDisplayName = nil
        appleAuthCode = nil
        appleRefreshToken = nil
    }
}
