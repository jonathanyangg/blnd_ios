@testable import blnd_ios
import Foundation
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

    @Test func decodesTheLiveNowPayload() throws {
        let json = Data(
            """
            {
              "movie": {
                "tmdb_id": 880001,
                "title": "Second Pick",
                "year": 2020,
                "overview": null,
                "poster_path": null,
                "genres": [{"id": 878, "name": "Science Fiction"}],
                "runtime": 120,
                "vote_average": 4.0,
                "trailer_url": null,
                "director": null,
                "cast": [],
                "tagline": null,
                "backdrop_path": null,
                "match_score": 1.0,
                "comment_count": 0
              },
              "reason": "Popular with people who like Science Fiction"
            }
            """.utf8
        )
        let pick = try JSONDecoder().decode(NowPickResponse.self, from: json)
        #expect(pick.movie.tmdbId == 880001)
        #expect(pick.movie.genres.first?.name == "Science Fiction")
        #expect(pick.reason.contains("Science Fiction"))
    }

    @Test func errorEnvelopeUsesMessageAndStringDetail() {
        let body = Data(
            """
            {"error":{"code":"VALIDATION_ERROR","message":"exclude must be comma-separated tmdb ids"},"detail":"exclude must be comma-separated tmdb ids"}
            """.utf8
        )
        #expect(apiErrorMessage(from: body) == "exclude must be comma-separated tmdb ids")
        let detailOnly = Data(#"{"detail":"No movie to recommend"}"#.utf8)
        #expect(apiErrorMessage(from: detailOnly) == "No movie to recommend")
    }
}
