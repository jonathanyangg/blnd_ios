@testable import blnd_ios
import Foundation
import Testing

@MainActor
struct WhereToWatchTests {
    private let apiBase = URL(string: "https://api.blnd.movie")!

    @Test func decodesWhereToWatchAndShowsTheAttributionField() throws {
        let response = try JSONDecoder().decode(
            StreamingAvailabilityResponse.self,
            from: Data(
                """
                {
                  "tmdb_id": 550,
                  "country": "us",
                  "options": [],
                  "where_to_watch": {
                    "country": "US",
                    "attribution": "JustWatch",
                    "link": "https://www.themoviedb.org/movie/550/watch?locale=US",
                    "flatrate": [
                      {
                        "provider_id": 8,
                        "provider_name": "Netflix",
                        "logo_path": "/netflix.jpg",
                        "web_url": "https://www.netflix.com/title/80057281",
                        "app_url": null,
                        "click_url": null,
                        "ios_link": null
                      }
                    ],
                    "rent": [],
                    "buy": []
                  }
                }
                """.utf8
            )
        )

        let watch = try #require(response.whereToWatch)
        #expect(watch.attribution == "JustWatch")
        #expect(watch.attributionURL.host == "www.themoviedb.org")
        let netflix = try #require(watch.offers(.watchNow).first)
        #expect(netflix.appUrl == nil)
        #expect(netflix.logoURL?.absoluteString == "https://image.tmdb.org/t/p/w92/netflix.jpg")
        let plan = try #require(netflix.openPlan(kind: .watchNow, apiBase: apiBase))
        #expect(plan.appLink == nil)
        #expect(plan.schemeLink == nil)
        #expect(plan.webLink.absoluteString == "https://www.netflix.com/title/80057281")
        #expect(!plan.webLink.absoluteString.contains("tag="))
    }

    @Test func watchNowTriesIosLinkThenClickUrl() throws {
        let offer = try offer(
            """
            {
              "provider_id": 119,
              "provider_name": "Amazon Prime Video",
              "logo_path": "/prime.jpg",
              "web_url": "https://www.amazon.com/gp/video/search?phrase=Fight%20Club",
              "app_url": "aiv://aiv/search?phrase=Fight%20Club",
              "click_url": "https://api.blnd.movie/out/119/movie/550",
              "ios_link": "aiv://aiv/search?phrase=Fight%20Club"
            }
            """
        )
        let plan = try #require(offer.openPlan(kind: .watchNow, apiBase: apiBase))
        #expect(plan.schemeLink?.scheme == "aiv")
        #expect(plan.appLink == nil)
        #expect(plan.webLink.absoluteString == "https://api.blnd.movie/out/119/movie/550")
        #expect(!plan.webLink.absoluteString.contains("tag="))
        #expect(!offer.webUrl.contains("tag="))
    }

    @Test func appleTvUsesTheHttpsLink() throws {
        let offer = try offer(
            """
            {
              "provider_id": 2,
              "provider_name": "Apple TV",
              "logo_path": "/apple.jpg",
              "web_url": "https://tv.apple.com/us/movie/fight-club",
              "app_url": null,
              "click_url": "https://api.blnd.movie/out/2/movie/550",
              "ios_link": "https://tv.apple.com/us/movie/fight-club"
            }
            """
        )
        let plan = try #require(offer.openPlan(kind: .watchNow, apiBase: apiBase))
        #expect(plan.appLink?.host == "tv.apple.com")
        #expect(plan.schemeLink == nil)
        #expect(plan.webLink.absoluteString == "https://api.blnd.movie/out/2/movie/550")
    }

    @Test func rentAndBuyStayOnTheClickURL() throws {
        let offer = try offer(
            """
            {
              "provider_id": 10,
              "provider_name": "Amazon Video",
              "logo_path": null,
              "web_url": "https://www.amazon.com/s?k=Fight+Club",
              "app_url": "aiv://aiv/search?phrase=Fight%20Club",
              "click_url": "/out/10/movie/550",
              "ios_link": "aiv://aiv/search?phrase=Fight%20Club"
            }
            """
        )
        let plan = try #require(offer.openPlan(kind: .rent, apiBase: apiBase))
        #expect(plan.appLink == nil)
        #expect(plan.schemeLink == nil)
        #expect(plan.webLink.absoluteString == "https://api.blnd.movie/out/10/movie/550")
    }

    @Test func unknownSchemeFallsThroughToTheWebURL() throws {
        let offer = try offer(
            """
            {
              "provider_id": 99,
              "provider_name": "X",
              "logo_path": null,
              "web_url": "https://example.com/title",
              "app_url": "javascript:alert(1)",
              "click_url": null,
              "ios_link": "javascript:alert(1)"
            }
            """
        )
        let plan = try #require(offer.openPlan(kind: .watchNow, apiBase: apiBase))
        #expect(plan.schemeLink == nil)
        #expect(plan.appLink == nil)
        #expect(plan.webLink.host == "example.com")
    }

    @Test func premiumHidesAffiliatePrompt() throws {
        let rent = try offer(
            """
            {
              "provider_id": 2,
              "provider_name": "Apple TV",
              "logo_path": null,
              "web_url": "https://tv.apple.com/us/movie/x",
              "app_url": null,
              "click_url": null,
              "ios_link": null
            }
            """
        )
        let watch = WhereToWatch(
            country: "US",
            attribution: "JustWatch",
            link: nil,
            flatrate: [],
            rent: [rent],
            buy: []
        )
        #expect(watch.showsAffiliatePrompt(isPremium: true) == false)
        #expect(watch.showsAffiliatePrompt(isPremium: false))
        let streamOnly = WhereToWatch(
            country: "US",
            attribution: "JustWatch",
            link: nil,
            flatrate: [rent],
            rent: [],
            buy: []
        )
        #expect(streamOnly.showsAffiliatePrompt(isPremium: false) == false)
    }

    @Test func duplicateProvidersCollapse() throws {
        let first = try offer(
            """
            {
              "provider_id": 8,
              "provider_name": "Netflix",
              "logo_path": "/a.jpg",
              "web_url": "https://www.netflix.com/title/1",
              "app_url": null,
              "click_url": null,
              "ios_link": null
            }
            """
        )
        let second = try offer(
            """
            {
              "provider_id": 8,
              "provider_name": "Netflix",
              "logo_path": "/b.jpg",
              "web_url": "https://www.netflix.com/title/1?q=sd",
              "app_url": null,
              "click_url": null,
              "ios_link": null
            }
            """
        )
        let watch = WhereToWatch(
            country: "US",
            attribution: "JustWatch",
            link: nil,
            flatrate: [first, second],
            rent: [],
            buy: []
        )
        #expect(watch.offers(.watchNow).count == 1)
        #expect(watch.offers(.watchNow).first?.logoPath == "/a.jpg")
    }

    @Test func declaredSchemesMatchThePlist() throws {
        let plistURL = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "blnd-ios-Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let declared = try #require(plist?["LSApplicationQueriesSchemes"] as? [String])
        #expect(Set(declared) == WatchOffer.querySchemes)
        #expect(declared.contains("aiv"))
    }

    private func offer(_ json: String) throws -> WatchOffer {
        try JSONDecoder().decode(WatchOffer.self, from: Data(json.utf8))
    }
}
