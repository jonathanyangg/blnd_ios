import Foundation

/// Wire contract for notes import.
///
/// `integration/overnight-2026-10-15` on blnd_backend has no `/import/notes` yet.
/// This is the shape that endpoint needs.
///
/// `POST /import/notes`
/// `{ "text": "Heat\nThe Godfather" }`
/// → `{ "items": [ { "query", "confidence": "high"|"low"|"none", "candidates": [Movie] } ] }`
///
/// `POST /import/notes/commit`
/// `{ "bucket": "watched"|"watchlist"|"interested", "tmdb_ids": [949] }`
/// → `{ "saved": 1, "recommendations": [Movie] }`
///
/// Movie is `{ "tmdb_id", "title", "year", "poster_path" }`.
/// `high` pre-checks the first candidate. `low` shows up to 3. `none` is a miss.
enum NotesImportError: Error, Equatable {
    case empty
    case tooLong
}

enum NotesImportBucket: String, CaseIterable, Identifiable {
    case watched
    case watchlist
    case interested

    var id: String { rawValue }

    var label: String {
        switch self {
        case .watched: "Watched"
        case .watchlist: "Watchlist"
        case .interested: "Interested"
        }
    }
}

struct NotesImportCandidate: Codable, Identifiable, Hashable {
    let tmdbId: Int
    let title: String
    let year: Int?
    let posterPath: String?

    var id: Int { tmdbId }

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title
        case year
        case posterPath = "poster_path"
    }
}

enum NotesMatchConfidence: String, Codable {
    case high
    case low
    case none
}

struct NotesImportLine: Codable, Equatable {
    let query: String
    let confidence: NotesMatchConfidence
    let candidates: [NotesImportCandidate]
}

struct NotesImportResponse: Codable, Equatable {
    let items: [NotesImportLine]
}

struct NotesImportRequestBody: Encodable {
    let text: String
}

struct NotesImportCommitBody: Encodable {
    let bucket: String
    let tmdbIds: [Int]

    enum CodingKeys: String, CodingKey {
        case bucket
        case tmdbIds = "tmdb_ids"
    }
}

struct NotesImportCommitResponse: Codable, Equatable {
    let saved: Int
    let recommendations: [NotesImportCandidate]

    enum CodingKeys: String, CodingKey {
        case saved
        case recommendations
    }

    init(saved: Int, recommendations: [NotesImportCandidate]) {
        self.saved = saved
        self.recommendations = recommendations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        saved = try container.decode(Int.self, forKey: .saved)
        recommendations = try container.decodeIfPresent([NotesImportCandidate].self, forKey: .recommendations) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(saved, forKey: .saved)
        try container.encode(recommendations, forKey: .recommendations)
    }
}

struct NotesReviewItem: Identifiable, Equatable {
    let id: Int
    let query: String
    let confidence: NotesMatchConfidence
    let candidates: [NotesImportCandidate]
    var picked: NotesImportCandidate?
    var isIncluded: Bool
}

enum NotesImportReview {
    /// shortcut: notes longer than this are rejected, raise it if real lists exceed it.
    static let maxCharacters = 50_000

    static func normalizedText(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw NotesImportError.empty }
        if trimmed.count > maxCharacters { throw NotesImportError.tooLong }
        return trimmed
    }

    /// High-confidence rows start checked. Low-confidence rows keep the top 3 and start unchecked.
    /// A miss drops any candidates so the screen can search instead.
    static func items(from response: NotesImportResponse) -> [NotesReviewItem] {
        response.items.enumerated().compactMap { index, line in
            let query = line.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return nil }
            switch line.confidence {
            case .high:
                guard let match = line.candidates.first else {
                    return miss(id: index, query: query)
                }
                return NotesReviewItem(
                    id: index,
                    query: query,
                    confidence: .high,
                    candidates: [match],
                    picked: match,
                    isIncluded: true
                )
            case .low:
                let choices = Array(line.candidates.prefix(3))
                guard !choices.isEmpty else { return miss(id: index, query: query) }
                return NotesReviewItem(
                    id: index,
                    query: query,
                    confidence: .low,
                    candidates: choices,
                    picked: nil,
                    isIncluded: false
                )
            case .none:
                return miss(id: index, query: query)
            }
        }
    }

    static func selectedIds(from items: [NotesReviewItem]) -> [Int] {
        var seen = Set<Int>()
        var ids: [Int] = []
        for item in items where item.isIncluded {
            guard let id = item.picked?.tmdbId, seen.insert(id).inserted else { continue }
            ids.append(id)
        }
        return ids
    }

    static func foundTitle(count: Int) -> String {
        let noun = count == 1 ? "movie" : "movies"
        return "We found \(count) \(noun)"
    }

    private static func miss(id: Int, query: String) -> NotesReviewItem {
        NotesReviewItem(
            id: id,
            query: query,
            confidence: .none,
            candidates: [],
            picked: nil,
            isIncluded: false
        )
    }
}
