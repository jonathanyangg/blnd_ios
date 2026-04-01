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

struct StreamingOption: Codable, Identifiable {
    let service: StreamingServiceInfo
    let type: String
    let link: String
    let quality: String?
    let price: StreamingPrice?
    let expiresSoon: Bool

    var id: String {
        "\(service.id)-\(type)-\(link)"
    }

    var typeLabel: String {
        switch type {
        case "subscription": return "Stream"
        case "free": return "Free"
        case "rent": return "Rent"
        case "buy": return "Buy"
        case "addon": return "Add-on"
        default: return type.capitalized
        }
    }

    var isStreamable: Bool {
        type == "subscription" || type == "free" || type == "addon"
    }

    enum CodingKeys: String, CodingKey {
        case service, type, link, quality, price
        case expiresSoon = "expires_soon"
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
