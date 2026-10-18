import Foundation

/// A person card from a timeline or watched-with response: `{id, name, avatar}`.
struct TimelinePerson: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let avatar: String?
}

/// Movie or show attached to a timeline row.
struct TimelineMedia: Decodable, Hashable {
    let tmdbId: Int
    let title: String
    let poster: String?
    let year: Int?
    let mediaType: MediaType

    var isTV: Bool { mediaType == .tv }

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title, poster, year
        case mediaType = "media_type"
    }
}

/// One dated watch. `id` and `created_at` are optional while the server rolls them out.
struct TimelineEntry: Decodable, Identifiable, Hashable {
    /// Watch-log row id. Absent on older payloads.
    let logId: Int?
    /// ISO8601, including fractional seconds such as `2026-10-15T08:14:59.352080Z`.
    let createdAt: String?
    /// Diary day, `YYYY-MM-DD`.
    let date: String?
    let rating: Double?
    let media: TimelineMedia
    /// Who logged the row. Replaces the old `watched_by` field.
    let user: TimelinePerson
    let watchedWith: [TimelinePerson]

    var id: String {
        if let logId { return "log-\(logId)" }
        return "\(media.tmdbId)|\(date ?? "")|\(user.id)|\(createdAt ?? "")"
    }

    init(
        logId: Int? = nil,
        createdAt: String? = nil,
        date: String? = nil,
        rating: Double? = nil,
        media: TimelineMedia,
        user: TimelinePerson,
        watchedWith: [TimelinePerson] = []
    ) {
        self.logId = logId
        self.createdAt = createdAt
        self.date = date
        self.rating = rating
        self.media = media
        self.user = user
        self.watchedWith = watchedWith
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logId = try container.decodeIfPresent(Int.self, forKey: .logId)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        media = try container.decode(TimelineMedia.self, forKey: .media)
        user = try container.decode(TimelinePerson.self, forKey: .user)
        watchedWith = try container.decodeIfPresent([TimelinePerson].self, forKey: .watchedWith) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case logId = "id"
        case createdAt = "created_at"
        case date, rating, media, user
        case watchedWith = "watched_with"
    }
}

/// Cursor page. `nextCursor == nil` means there is no further page.
struct TimelinePage: Decodable {
    let results: [TimelineEntry]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
    }
}

struct WatchedWithResponse: Decodable {
    let watchedWith: [TimelinePerson]

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

/// Diary sentence and the watched-with picker cap.
enum DiaryCopy {
    /// Server rejects more than 50 ids on `PUT /tracking/{tmdb_id}/watched-with`.
    static let maxCompanions = 50
    static let companionCapMessage = "You can tag up to 50 people."
    static let taggingUnavailable = "Tagging who you watched with isn't available yet."
    static let diaryUnavailableTitle = "Diary isn't available yet"
    static let diaryUnavailableMessage = "The timeline will show up here once the server update ships."

    /// "with Alex", "with Alex & Sam", or "with Alex, Sam & Jordan". Nil when nobody is tagged.
    static func watchedWithLine(_ people: [TimelinePerson]) -> String? {
        let names = people.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
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

    /// Adds `id` unless the set is already at `maxCompanions`. Removing always works.
    /// An empty set is a valid save: the server clears companions when `user_ids` is `[]`.
    static func toggle(_ id: String, in selected: Set<String>) -> (selected: Set<String>, hitCap: Bool) {
        if selected.contains(id) {
            var next = selected
            next.remove(id)
            return (next, false)
        }
        guard selected.count < maxCompanions else { return (selected, true) }
        var next = selected
        next.insert(id)
        return (next, false)
    }
}

enum TimelineLoadFailure: Equatable {
    case unavailable
    case message(String)

    static func from(_ error: Error) -> TimelineLoadFailure {
        if let api = error as? APIError, case .notFound = api {
            return .unavailable
        }
        return .message(UserFacingError.map(error).message)
    }
}

struct TimelineDay: Equatable {
    let year: Int
    let month: Int
    let day: Int
}

enum TimelineDate {
    /// Prefer the diary `date`. Otherwise the UTC day of `created_at`.
    static func dayParts(of entry: TimelineEntry, calendar: Calendar = .current) -> TimelineDay? {
        if let date = entry.date, let day = parseDay(date) { return day }
        guard let createdAt = entry.createdAt, let instant = parseTimestamp(createdAt) else { return nil }
        var utc = calendar
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? utc.timeZone
        let parts = utc.dateComponents([.year, .month, .day], from: instant)
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

    /// Accepts `2026-10-15T08:14:59.352080Z` (six fractional digits) and shorter forms.
    static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        if let shortened = milliseconds(value), let date = fractional.date(from: shortened) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let stripped = stripFraction(value), let date = plain.date(from: stripped) { return date }
        return plain.date(from: value)
    }

    /// `2026-10-15T08:14:59.352080Z` -> `2026-10-15T08:14:59.352Z`.
    static func milliseconds(_ value: String) -> String? {
        guard let dot = value.firstIndex(of: ".") else { return nil }
        let after = value[value.index(after: dot)...]
        let digits = after.prefix { $0.isNumber }
        guard digits.count > 3 else { return nil }
        let zone = after.dropFirst(digits.count)
        return "\(value[..<value.index(after: dot)])\(digits.prefix(3))\(zone)"
    }

    static func stripFraction(_ value: String) -> String? {
        guard let dot = value.firstIndex(of: ".") else { return nil }
        let after = value[value.index(after: dot)...]
        let digits = after.prefix { $0.isNumber }
        let zone = after.dropFirst(digits.count)
        return "\(value[..<dot])\(zone)"
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
                let leftId = lhs.0.logId ?? -1
                let rightId = rhs.0.logId ?? -1
                if leftId != rightId { return leftId > rightId }
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

enum APIErrorEnvelope {
    /// Reads `{error:{code,message}}`. Nil when that object is absent.
    static func message(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String,
              !message.isEmpty
        else { return nil }
        return message
    }

    static func message(in data: Data) -> String? {
        message(from: data)
    }
}
