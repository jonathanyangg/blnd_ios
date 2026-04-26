import Foundation

/// Deterministic dummy content used when `APIConfig.screenshotMode` is true.
///
/// App Store screenshots can't show copyrighted movie metadata (titles, cast,
/// overview text, percentages, etc. — see guideline 4.1(a) Copycats). This
/// helper returns consistent fake values keyed off the real `tmdbId` so the
/// same movie always renders with the same dummy content across screenshot
/// sessions. Genres are intentionally kept real since they're not IP.
enum ScreenshotDummy {
    static let titles = [
        "The Grand Heist",
        "Neon Horizon",
        "Silent Echo",
        "Midnight Run",
        "Crimson Tide",
        "Starfall",
        "The Last Signal",
        "Whispering Pines",
        "Broken Compass",
        "Golden Hour",
        "Paper Cities",
        "The Quiet Year",
        "Velvet Storm",
        "Shallow Graves",
        "Northern Lights",
        "The Wayfinder",
        "Silver Linings",
        "The Outlier",
        "Ember and Ash",
        "Lost Frequency",
    ]

    static let taglines = [
        "Some adventures change everything.",
        "Truth hides in plain sight.",
        "Every ending is a new beginning.",
        "The past never stays buried.",
        "One choice. One moment. One life.",
        "Courage has a price.",
        "Nothing is ever what it seems.",
        "A journey beyond the edge.",
        "Love. Loss. Legacy.",
        "Sometimes you have to lose to win.",
    ]

    static let overviews = [
        "A thrilling story of unexpected alliances and hidden truths. "
            + "When a chance encounter upends their ordinary lives, two "
            + "strangers find themselves drawn into a web of secrets. As "
            + "the stakes grow higher, they must decide what they're willing "
            + "to risk for a future neither of them saw coming.",
        "Set against a backdrop of sweeping landscapes, this intimate "
            + "drama follows a young traveler searching for answers about "
            + "their past. A meeting with an unlikely mentor sparks a "
            + "journey that will test everything they thought they knew.",
        "A sharp, surprising story about chosen family, second chances, "
            + "and the quiet courage it takes to start over. Told across "
            + "one unforgettable summer, it reminds us that the smallest "
            + "choices can change the shape of a life.",
    ]

    static let directors = [
        "Alex Morgan",
        "Jordan Lee",
        "Sam Rivera",
        "Taylor Kim",
        "Casey Ellis",
        "Riley Chen",
        "Morgan Hayes",
        "Quinn Parker",
    ]

    static let castNames = [
        "Alex Morgan",
        "Jordan Lee",
        "Sam Rivera",
        "Taylor Kim",
        "Casey Ellis",
        "Riley Chen",
        "Morgan Hayes",
        "Quinn Parker",
    ]

    static let friendUsernames = [
        "alexm",
        "jordanl",
        "samr",
        "taylork",
        "caseye",
        "rileyc",
    ]

    static let friendDisplayNames = [
        "Alex",
        "Jordan",
        "Sam",
        "Taylor",
        "Casey",
        "Riley",
    ]

    // MARK: - Deterministic lookups

    private static func index(for tmdbId: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return abs(tmdbId) % count
    }

    static func title(for tmdbId: Int) -> String {
        titles[index(for: tmdbId, count: titles.count)]
    }

    static func tagline(for tmdbId: Int) -> String {
        taglines[index(for: tmdbId, count: taglines.count)]
    }

    static func overview(for tmdbId: Int) -> String {
        overviews[index(for: tmdbId, count: overviews.count)]
    }

    static func director(for tmdbId: Int) -> String {
        directors[index(for: tmdbId, count: directors.count)]
    }

    /// Deterministic dummy match % in range [70, 95).
    static func matchPercent(for tmdbId: Int) -> Int {
        70 + (abs(tmdbId) % 25)
    }

    /// Deterministic dummy year in range [2019, 2025).
    static func year(for tmdbId: Int) -> Int {
        2019 + (abs(tmdbId) % 6)
    }

    /// Deterministic dummy runtime in minutes, range [95, 150).
    static func runtime(for tmdbId: Int) -> Int {
        95 + (abs(tmdbId) % 55)
    }

    /// Deterministic dummy vote average in range [3.5, 4.25), matching the
    /// backend's 0-10 -> 0-5 scaled rating that non-screenshot data uses.
    static func voteAverage(for tmdbId: Int) -> Double {
        3.5 + Double(abs(tmdbId) % 15) / 20.0
    }

    static func castName(at index: Int) -> String {
        castNames[index % castNames.count]
    }

    static func friendUsername(at index: Int) -> String {
        friendUsernames[index % friendUsernames.count]
    }

    static func friendDisplayName(at index: Int) -> String {
        friendDisplayNames[index % friendDisplayNames.count]
    }

    /// Generate `count` fake `FriendWatchedResponse` entries so the
    /// "Watched by" section is populated on every reel/detail card during
    /// screenshot mode. Avatars are nil → AvatarView falls back to its
    /// gradient circle so no real photos are exposed.
    static func friendsWhoWatched(count: Int = 6) -> [FriendWatchedResponse] {
        (0 ..< count).map { idx in
            FriendWatchedResponse(
                userId: "dummy-\(idx)",
                username: friendUsername(at: idx),
                displayName: friendDisplayName(at: idx),
                avatarUrl: nil,
                rating: 4.0 + Double(idx % 3) * 0.5,
                review: nil,
                watchedDate: nil
            )
        }
    }
}
