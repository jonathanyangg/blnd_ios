@testable import blnd_ios
import Foundation
import Testing

@MainActor
struct WhereToWatchTests {
    private let apiBase = URL(string: "https://api.blnd.movie")!

    @Test func decodesProviderLinksWithoutNewFields() throws {
        let option = try decode(
            """
            {
              "service": {"id": "netflix", "name": "Netflix"},
              "type": "subscription",
              "link": "https://www.netflix.com/title/80057281",
              "expires_soon": false
            }
            """
        )

        let plan = try #require(option.openPlan(apiBase: apiBase))
        #expect(plan.appLink?.host == "www.netflix.com")
        #expect(plan.schemeLink == nil)
        #expect(plan.webLink.absoluteString == "https://www.netflix.com/title/80057281")
        #expect(!plan.webLink.absoluteString.contains("tag="))
    }

    @Test func watchNowUsesUniversalLinkThenClickRedirect() throws {
        let option = try decode(
            """
            {
              "service": {"id": "prime", "name": "Prime Video"},
              "type": "flatrate",
              "link": "https://www.primevideo.com/detail/0ABC",
              "ios_link": "https://www.primevideo.com/detail/0ABC",
              "click_url": "https://api.blnd.movie/watch/click?offer=9",
              "expires_soon": false
            }
            """
        )

        let plan = try #require(option.openPlan(apiBase: apiBase))
        #expect(plan.appLink?.absoluteString == "https://www.primevideo.com/detail/0ABC")
        #expect(plan.webLink.absoluteString == "https://api.blnd.movie/watch/click?offer=9")
        #expect(!plan.webLink.absoluteString.contains("tag="))
    }

    @Test func rentAndBuyStayOnTheClickURL() throws {
        let option = try decode(
            """
            {
              "service": {"id": "amazon", "name": "Amazon"},
              "type": "rent",
              "link": "https://www.amazon.com/gp/video/detail/B00",
              "ios_link": "aiv://aiv/view?gti=B00",
              "click_url": "/watch/click?offer=3",
              "price": {"amount": "3.99", "currency": "USD", "formatted": "$3.99"},
              "expires_soon": false
            }
            """
        )

        let plan = try #require(option.openPlan(apiBase: apiBase))
        #expect(plan.appLink == nil)
        #expect(plan.schemeLink == nil)
        #expect(plan.webLink.absoluteString == "https://api.blnd.movie/watch/click?offer=3")
    }

    @Test func customSchemeIsOnlyUsedForKnownApps() throws {
        let netflix = try decode(
            """
            {
              "service": {"id": "netflix", "name": "Netflix"},
              "type": "subscription",
              "link": "https://www.netflix.com/title/1",
              "ios_link": "nflx://www.netflix.com/title/1",
              "expires_soon": false
            }
            """
        )
        let plan = try #require(netflix.openPlan(apiBase: apiBase))
        #expect(plan.schemeLink?.scheme == "nflx")
        #expect(plan.appLink == nil)

        let evil = try decode(
            """
            {
              "service": {"id": "x", "name": "X"},
              "type": "subscription",
              "link": "https://example.com/title",
              "ios_link": "javascript:alert(1)",
              "expires_soon": false
            }
            """
        )
        let blocked = try #require(evil.openPlan(apiBase: apiBase))
        #expect(blocked.schemeLink == nil)
        #expect(blocked.webLink.host == "example.com")
    }

    @Test func clickHostIsNotTreatedAsTheProviderApp() throws {
        let option = try decode(
            """
            {
              "service": {"id": "netflix", "name": "Netflix"},
              "type": "subscription",
              "link": "https://api.blnd.movie/watch/click?offer=1",
              "expires_soon": false
            }
            """
        )
        let plan = try #require(option.openPlan(apiBase: apiBase))
        #expect(plan.appLink == nil)
        #expect(plan.webLink.host == "api.blnd.movie")
    }

    @Test func premiumHidesAffiliatePrompt() throws {
        let rent = try decode(
            """
            {
              "service": {"id": "apple", "name": "Apple TV"},
              "type": "buy",
              "link": "https://tv.apple.com/us/movie/x",
              "expires_soon": false
            }
            """
        )
        #expect(WhereToWatchList.showsAffiliatePrompt(isPremium: true, options: [rent]) == false)
        #expect(WhereToWatchList.showsAffiliatePrompt(isPremium: false, options: [rent]))
        let stream = try decode(
            """
            {
              "service": {"id": "netflix", "name": "Netflix"},
              "type": "subscription",
              "link": "https://www.netflix.com/title/1",
              "expires_soon": false
            }
            """
        )
        #expect(WhereToWatchList.showsAffiliatePrompt(isPremium: false, options: [stream]) == false)
    }

    @Test func duplicateQualitiesCollapseToOneProvider() throws {
        let hd = try decode(
            """
            {
              "service": {"id": "netflix", "name": "Netflix"},
              "type": "subscription",
              "link": "https://www.netflix.com/title/1",
              "quality": "hd",
              "expires_soon": false
            }
            """
        )
        let sd = try decode(
            """
            {
              "service": {"id": "netflix", "name": "Netflix"},
              "type": "subscription",
              "link": "https://www.netflix.com/title/1?q=sd",
              "quality": "sd",
              "expires_soon": false
            }
            """
        )
        let rows = WhereToWatchList.offers(from: [hd, sd], kind: .watchNow)
        #expect(rows.count == 1)
        #expect(rows.first?.quality == "hd")
    }

    @Test func declaredSchemesMatchThePlist() throws {
        let plistURL = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "blnd-ios-Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let declared = try #require(plist?["LSApplicationQueriesSchemes"] as? [String])
        #expect(Set(declared) == StreamingOption.querySchemes)
    }

    private func decode(_ json: String) throws -> StreamingOption {
        try JSONDecoder().decode(StreamingOption.self, from: Data(json.utf8))
    }
}
