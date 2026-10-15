import Foundation

/// How a provider offer is sold. Watch now is the subscription (`flatrate`) group.
enum WatchOfferKind: String, CaseIterable {
    case watchNow
    case rent
    case buy

    var buttonTitle: String {
        switch self {
        case .watchNow: "Watch now"
        case .rent: "Rent"
        case .buy: "Buy"
        }
    }
}

/// What to open for one offer.
///
/// Watch now tries `appLink` (https universal link) or `schemeLink` (`aiv`)
/// before `webLink`. Rent and buy are web only so the click redirect stays
/// on the URL. The client never appends an affiliate tag.
struct WatchOpenPlan: Equatable {
    var appLink: URL?
    var schemeLink: URL?
    var webLink: URL
}

/// One provider row inside `where_to_watch`.
struct WatchOffer: Codable, Identifiable, Equatable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    let webUrl: String
    /// Raw app scheme when the server has one. Opening uses `iosLink`, not this.
    let appUrl: String?
    /// Public 302. Null when this provider is not on the redirect allow-list.
    let clickUrl: String?
    /// https universal link or the `aiv` scheme. Null for providers like Netflix.
    let iosLink: String?

    var id: String {
        "\(providerId)"
    }

    /// TMDB logo path, or an absolute logo URL.
    var logoURL: URL? {
        guard let logoPath = Self.nonEmpty(logoPath) else { return nil }
        if logoPath.hasPrefix("https://") || logoPath.hasPrefix("http://") {
            return URL(string: logoPath)
        }
        let path = logoPath.hasPrefix("/") ? logoPath : "/\(logoPath)"
        return URL(string: "https://image.tmdb.org/t/p/w92\(path)")
    }

    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
        case webUrl = "web_url"
        case appUrl = "app_url"
        case clickUrl = "click_url"
        case iosLink = "ios_link"
    }

    /// Custom schemes `canOpenURL` may ask about. The server only emits `aiv`.
    /// Keep this in sync with `LSApplicationQueriesSchemes`.
    static let querySchemes: Set<String> = ["aiv"]

    /// Watch now: `ios_link`, then `click_url`, then `web_url`.
    /// Rent and buy: `click_url`, then `web_url`.
    func openPlan(
        kind: WatchOfferKind,
        apiBase: URL? = URL(string: APIConfig.baseURL)
    ) -> WatchOpenPlan? {
        guard let web = Self.webURL(clickUrl, relativeTo: apiBase) ?? Self.webURL(webUrl, relativeTo: nil) else {
            return nil
        }
        guard kind == .watchNow, let deepRaw = Self.nonEmpty(iosLink) else {
            return WatchOpenPlan(appLink: nil, schemeLink: nil, webLink: web)
        }
        guard let deep = URL(string: deepRaw), let scheme = deep.scheme?.lowercased() else {
            return WatchOpenPlan(appLink: nil, schemeLink: nil, webLink: web)
        }
        if scheme == "https" || scheme == "http" {
            if deep.host?.lowercased() == apiBase?.host?.lowercased() {
                return WatchOpenPlan(appLink: nil, schemeLink: nil, webLink: web)
            }
            return WatchOpenPlan(appLink: deep, schemeLink: nil, webLink: web)
        }
        guard Self.querySchemes.contains(scheme) else {
            return WatchOpenPlan(appLink: nil, schemeLink: nil, webLink: web)
        }
        return WatchOpenPlan(appLink: nil, schemeLink: deep, webLink: web)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// http(s) only. Root-relative paths resolve against the API base.
    private static func webURL(_ raw: String?, relativeTo base: URL?) -> URL? {
        guard let raw = nonEmpty(raw) else { return nil }
        if raw.hasPrefix("/"), let base {
            return URL(string: raw, relativeTo: base)?.absoluteURL
        }
        guard let url = URL(string: raw), url.scheme == "https" || url.scheme == "http" else {
            return nil
        }
        return url
    }
}

/// TMDB watch providers for one country. `attribution` is the credit to show.
struct WhereToWatch: Codable, Equatable {
    let country: String
    let attribution: String
    let link: String?
    let flatrate: [WatchOffer]
    let rent: [WatchOffer]
    let buy: [WatchOffer]

    /// One row per provider. A later duplicate of the same provider is dropped.
    func offers(_ kind: WatchOfferKind) -> [WatchOffer] {
        let source: [WatchOffer]
        switch kind {
        case .watchNow: source = flatrate
        case .rent: source = rent
        case .buy: source = buy
        }
        var seen: Set<Int> = []
        return source.filter { offer in
            guard offer.openPlan(kind: kind) != nil else { return false }
            return seen.insert(offer.providerId).inserted
        }
    }

    var hasOffers: Bool {
        WatchOfferKind.allCases.contains { !offers($0).isEmpty }
    }

    /// Commission line for free accounts when a rental or purchase is listed.
    /// blnd+ never sees it. The rows and the attribution stay either way.
    func showsAffiliatePrompt(isPremium: Bool) -> Bool {
        guard !isPremium else { return false }
        return !offers(.rent).isEmpty || !offers(.buy).isEmpty
    }

    /// `where_to_watch.link` when it is http(s). Otherwise the JustWatch site.
    var attributionURL: URL {
        if let link, let url = URL(string: link), url.scheme == "https" || url.scheme == "http" {
            return url
        }
        return URL(string: "https://www.justwatch.com")!
    }

    enum CodingKeys: String, CodingKey {
        case country, attribution, link, flatrate, rent, buy
    }
}

struct StreamingAvailabilityResponse: Codable {
    let tmdbId: Int
    let country: String
    let whereToWatch: WhereToWatch?

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case country
        case whereToWatch = "where_to_watch"
    }
}
