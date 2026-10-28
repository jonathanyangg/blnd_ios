@testable import blnd_ios
import SwiftUI
import Testing

struct SearchResultTapTests {
    @Test func tvOpensTVDetailWithTheMovieRowButtonTrait() {
        #expect(SearchResultDestination.forMedia(.tv, tmdbId: 1396) == .tv(tmdbId: 1396))
        #expect(SearchResultDestination.forMedia(.movie, tmdbId: 550) == .movie(tmdbId: 550))
        #expect(SearchResultDestination.forMedia(nil, tmdbId: 550) == .movie(tmdbId: 550))
        #expect(SearchResultDestination.rowTraits == .isButton)
    }
}
