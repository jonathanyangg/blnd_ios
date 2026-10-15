@testable import blnd_ios
import Testing

struct NowPickTests {
    @Test func nowEndpointOmitsEmptyQuery() {
        #expect(NowPickQuery.endpoint(genre: nil, exclude: []) == "/recommendations/now")
        #expect(NowPickQuery.endpoint(genre: "  ", exclude: []) == "/recommendations/now")
    }

    @Test func nowEndpointKeepsCommaSeparatedExclude() {
        let endpoint = NowPickQuery.endpoint(genre: "Comedy", exclude: [900002, 900003])
        #expect(endpoint == "/recommendations/now?genre=Comedy&exclude=900002,900003")
    }

    @Test func rerollSkipsExcludedMovie() {
        let first = NowCatalog.pick(excluding: [])
        let second = NowCatalog.pick(excluding: [first.movie.tmdbId])
        #expect(first.movie.tmdbId != second.movie.tmdbId)
        #expect(first.reason == "Popular right now")
        #expect(second.reason == "Because it matches your taste")
    }

    @Test func lovedTitleBecomesTheReason() {
        let pick = NowCatalog.pick(excluding: [], lovedTitles: ["Parasite"])
        #expect(pick.reason == "Because you rated Parasite highly")
    }

    @Test func catalogStillReturnsAMovieWhenEveryIdIsExcluded() {
        let ids = NowCatalog.movies.map(\.tmdbId)
        let pick = NowCatalog.pick(excluding: ids)
        #expect(pick.movie.tmdbId == NowCatalog.movies[0].tmdbId)
    }
}
