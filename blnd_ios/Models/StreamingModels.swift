import Foundation

struct StreamingPrice: Codable {
    let amount: String
    let currency: String
    let formatted: String
}

struct StreamingServiceInfo: Codable {
    let id: String
    let name: String
    let logoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case logoUrl = "logo_url"
    }
}

/// How a provider offer is sold. Watch now covers subscriptions and free streams.
enum WatchOfferKind: String, CaseIterable {
    case watchNow
    case rent
    case buy

    init?(type: String) {
        switch type.lowercased() {
        case "subscription", "free", "addon", "flatrate", "ads":
            self = .watchNow
        case "rent":
            self = .rent
        case "buy":
            self = .buy
        default:
            return nil
        }
    }

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
/// Watch now tries `appLink` (https universal link) or `schemeLink` (provider
/// app) before `webLink`. Rent and buy are web only so the click redirect and
/// any server-side affiliate tag stay on the URL.
struct WatchOpenPlan: Equatable {
    var appLink: URL?
    var schemeLink: URL?
    var webLink: URL
}

struct StreamingOption: Codable, Identifiable {
    let service: StreamingServiceInfo
    let type: String
    let link: String
    /// Provider universal link or app scheme for the title. Optional until the backend sends it.
    let iosLink: String?
    /// Absolute or root-relative click-redirect URL. The server adds the Amazon tag when it is set.
    let clickUrl: String?
    let quality: String?
    let price: StreamingPrice?
    let expiresSoon: Bool

    var id: String {
        "\(service.id)-\(type)-\(link)"
    }

    var kind: WatchOfferKind? {
        WatchOfferKind(type: type)
    }

    enum CodingKeys: String, CodingKey {
        case service, type, link, quality, price
        case iosLink = "ios_link"
        case clickUrl = "click_url"
        case expiresSoon = "expires_soon"
    }

    /// Custom schemes `canOpenURL` is allowed to ask about. Keep this in sync
    /// with `LSApplicationQueriesSchemes` in `blnd-ios-Info.plist`.
    static let querySchemes: Set<String> = [
        "nflx",
        "aiv",
        "primevideo",
        "amazon",
        "amzn",
        "videos",
        "appletv",
        "hulu",
        "max",
        "hbomax",
        "disneyplus",
        "paramountplus",
        "peacock",
        "starz",
        "showtime",
        "mubi",
        "tubitv",
        "plutotv",
        "crunchyroll",
    ]

    /// Builds the open plan. Does not add an affiliate tag; the click URL is used unchanged.
    func openPlan(apiBase: URL? = URL(string: APIConfig.baseURL)) -> WatchOpenPlan? {
        guard let web = Self.webURL(clickUrl, relativeTo: apiBase) ?? Self.webURL(link, relativeTo: nil) else {
            return nil
        }
        guard kind == .watchNow else {
            return WatchOpenPlan(appLink: nil, schemeLink: nil, webLink: web)
        }

        let deepRaw = Self.nonEmpty(iosLink) ?? link
        guard let deep = URL(string: deepRaw), let scheme = deep.scheme?.lowercased() else {
            return WatchOpenPlan(appLink: nil, schemeLink: nil, webLink: web)
        }
        if scheme == "https" || scheme == "http" {
            let apiHost = apiBase?.host?.lowercased()
            if deep.host?.lowercased() == apiHost {
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
        guard let url = URL(string: raw),
              url.scheme == "https" || url.scheme == "http"
        else { return nil }
        return url
    }
}

enum WhereToWatchList {
    /// One row per provider. Later duplicates (another quality of the same offer) are dropped.
    static func offers(
        from options: [StreamingOption],
        kind: WatchOfferKind
    ) -> [StreamingOption] {
        var seen: Set<String> = []
        return options.filter { option in
            guard option.kind == kind, option.openPlan() != nil else { return false }
            return seen.insert(option.service.id).inserted
        }
    }

    /// Commission line for free accounts when a rental or purchase is listed.
    /// blnd+ never sees it. The Where to watch rows stay either way.
    static func showsAffiliatePrompt(
        isPremium: Bool,
        options: [StreamingOption]
    ) -> Bool {
        guard !isPremium else { return false }
        return !offers(from: options, kind: .rent).isEmpty
            || !offers(from: options, kind: .buy).isEmpty
    }
}

struct StreamingAvailabilityResponse: Codable {
    let tmdbId: Int
    let country: String
    let options: [StreamingOption]

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case country, options
    }
}
