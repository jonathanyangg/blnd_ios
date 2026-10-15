import Foundation
import Observation

/// Inclusive release years. A nil bound means that side is open.
struct YearSpan: Equatable, Sendable {
    var min: Int?
    var max: Int?
}

/// Chips in the catalog filter. New releases follows `calendarYear`.
enum ReleasePreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case newReleases
    case twenties
    case tens
    case twoThousands
    case nineties
    case classics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newReleases: "New releases"
        case .twenties: "2020s"
        case .tens: "2010s"
        case .twoThousands: "2000s"
        case .nineties: "90s"
        case .classics: "Classics"
        }
    }

    /// Maps a chip to the years it includes.
    /// Classics is everything through 1989. New releases is that calendar year only.
    func range(calendarYear: Int) -> YearSpan {
        switch self {
        case .newReleases:
            YearSpan(min: calendarYear, max: calendarYear)
        case .twenties:
            YearSpan(min: 2020, max: 2029)
        case .tens:
            YearSpan(min: 2010, max: 2019)
        case .twoThousands:
            YearSpan(min: 2000, max: 2009)
        case .nineties:
            YearSpan(min: 1990, max: 1999)
        case .classics:
            YearSpan(min: nil, max: 1989)
        }
    }

    static func matching(min: Int?, max: Int?, calendarYear: Int) -> ReleasePreset? {
        let span = YearSpan(min: min, max: max)
        return allCases.first { $0.range(calendarYear: calendarYear) == span }
    }
}

/// Movies, TV, or both, plus an optional release window.
enum MediaKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case movies = "movie"
    case tv
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .movies: "Movies"
        case .tv: "TV"
        case .all: "All"
        }
    }
}

/// Shared catalog filter. Persisted per user.
/// Sends `media_type`, `year_min`, and `year_max` only when those bounds are set.
struct CatalogFilter: Codable, Equatable, Sendable {
    var media: MediaKind = .all
    var yearMin: Int?
    var yearMax: Int?
    var preset: ReleasePreset?

    static let sliderLower = 1920

    /// One year past the 2020s, so dragging to the end means "no cap"
    /// and the 2020s chip can still store 2029.
    static func sliderUpper(calendarYear: Int) -> Int {
        max(calendarYear, 2030)
    }

    var isActive: Bool {
        media != .all || yearMin != nil || yearMax != nil
    }

    var chipTitle: String {
        guard isActive else { return "All" }
        var parts: [String] = []
        if media != .all { parts.append(media.label) }
        if let preset {
            parts.append(preset.title)
        } else if yearMin != nil || yearMax != nil {
            parts.append(yearLabel)
        }
        return parts.joined(separator: " · ")
    }

    var yearLabel: String {
        switch (yearMin, yearMax) {
        case let (min?, max?): "\(min)–\(max)"
        case let (min?, nil): "\(min)+"
        case let (nil, max?): "Through \(max)"
        default: ""
        }
    }

    mutating func apply(_ preset: ReleasePreset, calendarYear: Int) {
        let span = preset.range(calendarYear: calendarYear)
        yearMin = span.min
        yearMax = span.max
        self.preset = preset
    }

    mutating func setYearMin(_ year: Int, calendarYear: Int) {
        let upper = yearMax ?? Self.sliderUpper(calendarYear: calendarYear)
        let clamped = min(max(year, Self.sliderLower), upper)
        yearMin = clamped <= Self.sliderLower ? nil : clamped
        preset = ReleasePreset.matching(min: yearMin, max: yearMax, calendarYear: calendarYear)
    }

    mutating func setYearMax(_ year: Int, calendarYear: Int) {
        let lower = yearMin ?? Self.sliderLower
        let clamped = max(min(year, Self.sliderUpper(calendarYear: calendarYear)), lower)
        let ceiling = Self.sliderUpper(calendarYear: calendarYear)
        yearMax = clamped >= ceiling ? nil : clamped
        preset = ReleasePreset.matching(min: yearMin, max: yearMax, calendarYear: calendarYear)
    }

    /// Query pairs in send order. Empty when the filter should be omitted.
    var queryItems: [(name: String, value: String)] {
        var items: [(String, String)] = []
        if media != .all {
            items.append(("media_type", media.rawValue))
        }
        if let yearMin {
            items.append(("year_min", String(yearMin)))
        }
        if let yearMax {
            items.append(("year_max", String(yearMax)))
        }
        return items
    }

    /// Appends media and year params. Leaves the endpoint unchanged when nothing is set.
    func appending(to endpoint: String) -> String {
        let extra = queryItems.map { "\($0.name)=\($0.value)" }.joined(separator: "&")
        guard !extra.isEmpty else { return endpoint }
        let joiner = endpoint.contains("?") ? "&" : "?"
        return endpoint + joiner + extra
    }

    /// Client fallback. Legacy rows with no media type count as movies.
    /// A year window drops rows that have no year.
    func matches(mediaType: MediaType?, year: Int?) -> Bool {
        if media == .movies, mediaType == .tv { return false }
        if media == .tv, mediaType != .tv { return false }
        if yearMin != nil || yearMax != nil {
            guard let year else { return false }
            if let yearMin, year < yearMin { return false }
            if let yearMax, year > yearMax { return false }
        }
        return true
    }
}

/// `GET /recommendations/now` for Find a movie now (PR #17, not on main yet).
/// That screen should request this endpoint and put `CatalogFilterButton` in its top bar.
enum FindNowCatalogFilter {
    static func endpoint(
        genre: String?,
        exclude: [Int],
        filter: CatalogFilter
    ) -> String {
        var parts: [String] = []
        let trimmed = genre?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            let encoded = trimmed.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) ?? trimmed
            parts.append("genre=\(encoded)")
        }
        if !exclude.isEmpty {
            parts.append("exclude=\(exclude.map(String.init).joined(separator: ","))")
        }
        let base = parts.isEmpty
            ? "/recommendations/now"
            : "/recommendations/now?\(parts.joined(separator: "&"))"
        return filter.appending(to: base)
    }
}

/// One filter for the signed-in user, stored in UserDefaults.
@MainActor
@Observable
final class CatalogFilterStore {
    static let shared = CatalogFilterStore()

    private(set) var userId = ""
    var filter = CatalogFilter()

    func current() -> CatalogFilter {
        reloadForCurrentUser()
        return filter
    }

    func reloadForCurrentUser() {
        let id = KeychainManager.readString(key: "userId") ?? "signed-out"
        guard id != userId else { return }
        userId = id
        let stored = Self.load(userId: id)
        if stored != filter {
            filter = stored
        }
    }

    func update(_ newFilter: CatalogFilter) {
        reloadForCurrentUser()
        guard newFilter != filter else { return }
        filter = newFilter
        Self.save(filter, userId: userId)
    }

    nonisolated static func storageKey(_ userId: String) -> String {
        "blnd.catalogFilter.\(userId)"
    }

    nonisolated static func load(
        userId: String,
        defaults: UserDefaults = .standard
    ) -> CatalogFilter {
        guard let data = defaults.data(forKey: storageKey(userId)),
              let stored = try? JSONDecoder().decode(CatalogFilter.self, from: data)
        else { return CatalogFilter() }
        return stored
    }

    nonisolated static func save(
        _ filter: CatalogFilter,
        userId: String,
        defaults: UserDefaults = .standard
    ) {
        guard let data = try? JSONEncoder().encode(filter) else { return }
        defaults.set(data, forKey: storageKey(userId))
    }
}
