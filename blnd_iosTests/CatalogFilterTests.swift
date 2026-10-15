@testable import blnd_ios
import Foundation
import Testing

struct CatalogFilterTests {
    @Test func eachReleasePresetMapsToAYearRange() {
        let year = 2026
        #expect(
            ReleasePreset.newReleases.range(calendarYear: year)
                == YearSpan(min: 2026, max: 2026)
        )
        #expect(
            ReleasePreset.newReleases.range(calendarYear: 2031)
                == YearSpan(min: 2031, max: 2031)
        )
        #expect(ReleasePreset.twenties.range(calendarYear: year) == YearSpan(min: 2020, max: 2029))
        #expect(ReleasePreset.tens.range(calendarYear: year) == YearSpan(min: 2010, max: 2019))
        #expect(
            ReleasePreset.twoThousands.range(calendarYear: year)
                == YearSpan(min: 2000, max: 2009)
        )
        #expect(ReleasePreset.nineties.range(calendarYear: year) == YearSpan(min: 1990, max: 1999))
        #expect(ReleasePreset.classics.range(calendarYear: year) == YearSpan(min: nil, max: 1989))
    }

    @Test func queryOmitsUnsetMediaAndYears() {
        let open = CatalogFilter()
        #expect(open.queryItems.isEmpty)
        #expect(open.appending(to: "/movies/search?query=dune") == "/movies/search?query=dune")

        var classics = CatalogFilter()
        classics.apply(.classics, calendarYear: 2026)
        #expect(
            classics.appending(to: "/movies/search?query=dune")
                == "/movies/search?query=dune&year_max=1989"
        )

        var narrowed = CatalogFilter()
        narrowed.media = .tv
        narrowed.apply(.tens, calendarYear: 2026)
        #expect(
            narrowed.appending(to: "/recommendations/me/feed")
                == "/recommendations/me/feed?media_type=tv&year_min=2010&year_max=2019"
        )
    }

    @Test func clientFallbackUsesMediaAndYear() {
        var filter = CatalogFilter()
        filter.media = .tv
        filter.apply(.twenties, calendarYear: 2026)

        #expect(filter.matches(mediaType: .tv, year: 2021))
        #expect(filter.matches(mediaType: .tv, year: 2020))
        #expect(filter.matches(mediaType: .tv, year: 2029))
        #expect(!filter.matches(mediaType: .movie, year: 2021))
        #expect(!filter.matches(mediaType: .tv, year: 2019))
        #expect(filter.matches(mediaType: nil, year: 2021))
        #expect(filter.matches(mediaType: .tv, year: nil))

        var movies = CatalogFilter()
        movies.media = .movies
        #expect(movies.matches(mediaType: nil, year: nil))
        #expect(movies.matches(mediaType: .movie, year: 1972))
        #expect(!movies.matches(mediaType: .tv, year: 2011))
    }

    @Test func nullYearAndMissingMediaTypePass() throws {
        var filter = CatalogFilter()
        filter.media = .tv
        filter.apply(.twenties, calendarYear: 2026)

        #expect(filter.matches(mediaType: nil, year: nil))
        #expect(filter.matches(mediaType: nil, year: 2024))
        #expect(filter.matches(mediaType: .tv, year: nil))
        #expect(!filter.matches(mediaType: .movie, year: nil))
        #expect(!filter.matches(mediaType: nil, year: 1994))

        let watched = try JSONDecoder().decode(
            WatchedMovieResponse.self,
            from: Data("""
            {"id":1,"tmdb_id":1,"title":"Lost year","liked":false,"year":null,"created_at":"2026-01-01T00:00:00Z"}
            """.utf8)
        )
        let watchlist = try JSONDecoder().decode(
            WatchlistMovieResponse.self,
            from: Data("""
            {"id":2,"tmdb_id":2,"title":"No type","year":null,"genres":[],"cast":[],"created_at":"2026-01-01T00:00:00Z","media_type":null}
            """.utf8)
        )
        let blend = try JSONDecoder().decode(
            GroupRecMovieResponse.self,
            from: Data("""
            {"tmdb_id":3,"title":"Blend","year":null,"genres":[],"cast":[],"match_score":0.5}
            """.utf8)
        )

        for row in [
            (watched.mediaType, watched.year),
            (watchlist.mediaType, watchlist.year),
            (blend.mediaType, blend.year),
        ] {
            #expect(row.0 == nil)
            #expect(row.1 == nil)
            #expect(filter.matches(mediaType: row.0, year: row.1))
        }
    }

    @Test func searchKeepsMoviesAndTVOnSeparateRoutes() {
        var filter = CatalogFilter()
        filter.media = .tv
        filter.apply(.twenties, calendarYear: 2026)
        let path = filter.yearsOnly.appending(to: "/tv/search?query=the")
        #expect(!path.contains("media_type"))
        #expect(path.contains("year_min=2020"))
        #expect(path.contains("year_max=2029"))

        let movie = MovieResponse(show: TVShowResponse(
            tmdbId: 1,
            title: "Show",
            year: 2024,
            overview: nil,
            posterPath: nil,
            mediaType: .tv
        ))
        let same = MovieResponse(show: TVShowResponse(
            tmdbId: 1,
            title: "Show again",
            year: 2024,
            overview: nil,
            posterPath: nil,
            mediaType: .tv
        ))
        let other = MovieResponse(show: TVShowResponse(
            tmdbId: 2,
            title: "Other",
            year: nil,
            overview: nil,
            posterPath: nil,
            mediaType: .tv
        ))
        let merged = CatalogSearch.merge(movies: [movie], shows: [same, other])
        #expect(merged.map(\.tmdbId) == [1, 2])
        #expect(merged[0].title == "Show")
    }

    @Test func errorEnvelopeMessage() {
        let data = Data("""
        {"error":{"code":"invalid_filter","message":"year_min is too small"}}
        """.utf8)
        #expect(APIErrorEnvelope.message(in: data) == "year_min is too small")
        let error = APIError.decode(status: 400, data: data)
        guard case let .badRequest(info) = error else {
            Issue.record("expected badRequest")
            return
        }
        #expect(info.raw == "year_min is too small")
    }

    @Test func findNowEndpointCarriesFilterWhenSet() {
        var filter = CatalogFilter()
        filter.media = .movies
        filter.apply(.newReleases, calendarYear: 2026)
        let endpoint = FindNowCatalogFilter.endpoint(
            genre: "Drama",
            exclude: [1, 2],
            filter: filter
        )
        #expect(endpoint.contains("genre=Drama"))
        #expect(endpoint.contains("exclude=1,2"))
        #expect(endpoint.contains("media_type=movie"))
        #expect(endpoint.contains("year_min=2026"))
        #expect(endpoint.contains("year_max=2026"))

        let open = FindNowCatalogFilter.endpoint(genre: nil, exclude: [], filter: CatalogFilter())
        #expect(open == "/recommendations/now")
    }

    @Test func sliderDropsTheFloorAndClearsAPreset() {
        var filter = CatalogFilter()
        filter.apply(.nineties, calendarYear: 2026)
        filter.setYearMin(1995, calendarYear: 2026)
        #expect(filter.preset == nil)
        #expect(filter.yearMin == 1995)
        #expect(filter.yearMax == 1999)

        filter.setYearMin(CatalogFilter.sliderLower, calendarYear: 2026)
        #expect(filter.yearMin == nil)

        filter.setYearMax(CatalogFilter.sliderUpper(calendarYear: 2026), calendarYear: 2026)
        #expect(filter.yearMax == nil)
        #expect(filter.queryItems.isEmpty)
    }

    @Test func filterPersistsPerUser() {
        let suite = "CatalogFilterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        var saved = CatalogFilter()
        saved.media = .tv
        saved.apply(.nineties, calendarYear: 2026)
        CatalogFilterStore.save(saved, userId: "user-a", defaults: defaults)
        CatalogFilterStore.save(CatalogFilter(), userId: "user-b", defaults: defaults)

        let loaded = CatalogFilterStore.load(userId: "user-a", defaults: defaults)
        #expect(loaded.media == .tv)
        #expect(loaded.preset == .nineties)
        #expect(loaded.yearMin == 1990)
        #expect(loaded.yearMax == 1999)
        #expect(CatalogFilterStore.load(userId: "user-b", defaults: defaults) == CatalogFilter())
    }
}
