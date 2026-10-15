@testable import blnd_ios
import Foundation
import Testing

struct BlndIOSTests {
    @Test func example() {}

    @Test func resolvesReleaseAPIBaseURL() {
        let url = APIConfig.resolvedBaseURL(["API_BASE_URL": "https://blnd-backend.onrender.com"])
        #expect(url == "https://blnd-backend.onrender.com")
    }

    @Test func resolvesDebugLANAPIBaseURL() {
        let url = APIConfig.resolvedBaseURL(["API_BASE_URL": " http://192.168.7.121:8000 "])
        #expect(url == "http://192.168.7.121:8000")
    }

    @Test func decodeTVSearchResponse() throws {
        let json = """
        {
          "results": [
            {
              "tmdb_id": 1399,
              "title": "Game of Thrones",
              "year": 2011,
              "poster_path": "/tv-poster.jpg",
              "media_type": "tv"
            }
          ],
          "total_results": 1
        }
        """
        let data = Data(json.utf8)

        let response = try JSONDecoder().decode(TVSearchResponse.self, from: data)

        #expect(response.totalResults == 1)
        #expect(response.results.first?.tmdbId == 1399)
        #expect(response.results.first?.title == "Game of Thrones")
        #expect(response.results.first?.year == 2011)
        #expect(response.results.first?.mediaType == .tv)
    }

    @Test func decodeMovieResponseWithoutMediaType() throws {
        let json = """
        {
          "tmdb_id": 550,
          "title": "Fight Club",
          "genres": [],
          "cast": []
        }
        """
        let data = Data(json.utf8)

        let movie = try JSONDecoder().decode(MovieResponse.self, from: data)

        #expect(movie.mediaType == nil)
    }

    @Test func tvBadgeDecisionUsesMediaType() {
        #expect(MovieCard(mediaType: .tv).isTV)
        #expect(!MovieCard(mediaType: .movie).isTV)
        #expect(!MovieCard().isTV)
    }
}
