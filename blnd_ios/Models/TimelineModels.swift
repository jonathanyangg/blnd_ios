import Foundation

/// A person attached to a watch: either someone you watched with, or the member who logged a blend entry.
struct WatchCompanion: Decodable, Identifiable, Hashable {
    let userId: String
    let username: String
    let displayName: String?
    let avatarUrl: String?

    var id: String { userId }

    /// Name shown in the diary. Falls back to the username when the display name is blank.
    var name: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? username : trimmed
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

/// One dated watch on a profile diary or a blend timeline.
struct TimelineEntry: Decodable, Identifiable, Hashable {
    let id: Int
    let tmdbId: Int
    let title: String
    let posterPath: String?
    let year: Int?
    let rating: Double?
    let watchedDate: String?
    let createdAt: String?
    let watchedWith: [WatchCompanion]
    let watchedBy: WatchCompanion?

    init(
        id: Int,
        tmdbId: Int,
        title: String,
        posterPath: String? = nil,
        year: Int? = nil,
        rating: Double? = nil,
        watchedDate: String? = nil,
        createdAt: String? = nil,
        watchedWith: [WatchCompanion] = [],
        watchedBy: WatchCompanion? = nil
    ) {
        self.id = id
        self.tmdbId = tmdbId
        self.title = title
        self.posterPath = posterPath
        self.year = year
        self.rating = rating
        self.watchedDate = watchedDate
        self.createdAt = createdAt
        self.watchedWith = watchedWith
        self.watchedBy = watchedBy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        tmdbId = try container.decode(Int.self, forKey: .tmdbId)
        title = try container.decode(String.self, forKey: .title)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        watchedDate = try container.decodeIfPresent(String.self, forKey: .watchedDate)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        watchedWith = try container.decodeIfPresent([WatchCompanion].self, forKey: .watchedWith) ?? []
        watchedBy = try container.decodeIfPresent(WatchCompanion.self, forKey: .watchedBy)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case title
        case posterPath = "poster_path"
        case year, rating
        case watchedDate = "watched_date"
        case createdAt = "created_at"
        case watchedWith = "watched_with"
        case watchedBy = "watched_by"
    }
}

struct TimelinePage: Decodable {
    let results: [TimelineEntry]
    let total: Int
}

struct WatchedWithResponse: Decodable {
    let watchedWith: [WatchCompanion]

    enum CodingKeys: String, CodingKey {
        case watchedWith = "watched_with"
    }
}

struct SetWatchedWithRequest: Encodable {
    let userIds: [String]

    enum CodingKeys: String, CodingKey {
        case userIds = "user_ids"
    }
}

/// Diary sentence for the people a movie was watched with.
enum DiaryCopy {
    static let taggingUnavailable = "Tagging who you watched with isn't available yet."
    static let diaryUnavailableTitle = "Diary isn't available yet"
    static let diaryUnavailableMessage = "The timeline will show up here once the server update ships."

    /// "with Alex", "with Alex & Sam", or "with Alex, Sam & Jordan". Nil when nobody is tagged.
    static func watchedWithLine(_ people: [WatchCompanion]) -> String? {
        let names = people.map(\.name).filter { !$0.isEmpty }
        switch names.count {
        case 0:
            return nil
        case 1:
            return "with \(names[0])"
        case 2:
            return "with \(names[0]) & \(names[1])"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "with \(head) & \(names[names.count - 1])"
        }
    }
}

enum TimelineLoadFailure: Equatable {
    case unavailable
    case message(String)

    static func from(_ error: Error) -> TimelineLoadFailure {
        if let api = error as? APIError, case .notFound = api {
            return .unavailable
        }
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return .message(text)
    }
}

struct TimelineDay: Equatable {
    let year: Int
    let month: Int
    let day: Int
}

enum TimelineDate {
    /// Prefer the calendar `watched_date`. Otherwise the local day of `created_at`.
    static func dayParts(of entry: TimelineEntry, calendar: Calendar = .current) -> TimelineDay? {
        if let watchedDate = entry.watchedDate, let day = parseDay(watchedDate) {
            return day
        }
        guard let createdAt = entry.createdAt, let date = parseTimestamp(createdAt) else { return nil }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return TimelineDay(year: year, month: month, day: day)
    }

    static func parseDay(_ value: String) -> TimelineDay? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1 ... 12).contains(month),
              (1 ... 31).contains(day)
        else { return nil }
        return TimelineDay(year: year, month: month, day: day)
    }

    static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    static func monthName(_ month: Int) -> String {
        let names = [
            "", "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        guard names.indices.contains(month) else { return "" }
        return names[month]
    }

    static func weekdayAndDay(_ day: TimelineDay, calendar: Calendar = .current) -> String {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        guard let date = calendar.date(from: components) else { return "\(day.day)" }
        let weekday = calendar.component(.weekday, from: date)
        let symbol = calendar.shortWeekdaySymbols[weekday - 1]
        return "\(symbol) \(day.day)"
    }
}

struct TimelineSection: Identifiable {
    let id: String
    let title: String
    let entries: [TimelineEntry]
}

enum TimelineGrouping {
    /// Newest month first. Undated entries sit in a final "No date" section.
    static func sections(from entries: [TimelineEntry], calendar: Calendar = .current) -> [TimelineSection] {
        let dated = entries.map { ($0, TimelineDate.dayParts(of: $0, calendar: calendar)) }
        var buckets: [String: (order: Int, title: String, rows: [(TimelineEntry, TimelineDay?)])] = [:]

        for (entry, day) in dated {
            let key: String
            let title: String
            let order: Int
            if let day {
                key = String(format: "%04d-%02d", day.year, day.month)
                title = "\(TimelineDate.monthName(day.month)) \(day.year)"
                order = day.year * 100 + day.month
            } else {
                key = "undated"
                title = "No date"
                order = -1
            }
            var bucket = buckets[key] ?? (order, title, [])
            bucket.rows.append((entry, day))
            buckets[key] = bucket
        }

        return buckets.map { key, bucket in
            let rows = bucket.rows.sorted { lhs, rhs in
                let left = lhs.1.map { $0.year * 10_000 + $0.month * 100 + $0.day } ?? -1
                let right = rhs.1.map { $0.year * 10_000 + $0.month * 100 + $0.day } ?? -1
                if left != right { return left > right }
                return lhs.0.id > rhs.0.id
            }
            return TimelineSection(id: key, title: bucket.title, entries: rows.map(\.0))
        }
        .sorted { lhs, rhs in
            let left = buckets[lhs.id]?.order ?? -1
            let right = buckets[rhs.id]?.order ?? -1
            return left > right
        }
    }
}
