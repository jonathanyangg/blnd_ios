import Foundation

/// A title the user opened on a provider, waiting for a "Did you watch it?" prompt.
struct PendingWatch: Codable, Equatable, Identifiable {
    let tmdbId: Int
    let title: String
    let posterPath: String?
    let openedAt: Date
    var promptCount = 0
    var snoozedUntil: Date?

    var id: Int {
        tmdbId
    }
}

/// The newest `PendingWatch`, on device. Entries older than 12h are dropped.
struct PendingWatchStore {
    static let key = "blnd.pendingWatch"
    static let lifetime: TimeInterval = 12 * 3600

    var defaults: UserDefaults = .standard
    var now: () -> Date = Date.init

    func record(_ watch: PendingWatch) {
        defaults.set(try? JSONEncoder().encode(watch), forKey: Self.key)
    }

    func load() -> PendingWatch? {
        guard let watch = defaults.data(forKey: Self.key)
            .flatMap({ try? JSONDecoder().decode(PendingWatch.self, from: $0) })
        else { return nil }
        guard now().timeIntervalSince(watch.openedAt) <= Self.lifetime else {
            clear()
            return nil
        }
        return watch
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }

    /// Call when a provider opens from the hub, feed, or watchlist.
    func opened(tmdbId: Int, title: String, posterPath: String?) {
        record(PendingWatch(tmdbId: tmdbId, title: title, posterPath: posterPath, openedAt: now()))
    }
}

/// When to ask "Did you watch <title>?" after the app comes back to the foreground.
struct PostWatchPrompt {
    var store = PendingWatchStore()
    var minElapsed: TimeInterval = 20 * 60
    var snoozeInterval: TimeInterval = 2 * 3600
    var maxPrompts = 2

    /// The pending watch to ask about now, counted as shown. Drops it when the
    /// title is already watched or was asked `maxPrompts` times.
    func next(isWatched: (Int) async -> Bool) async -> PendingWatch? {
        guard var watch = store.load() else { return nil }
        let now = store.now()
        guard now.timeIntervalSince(watch.openedAt) >= minElapsed else { return nil }
        if let snoozedUntil = watch.snoozedUntil, now < snoozedUntil { return nil }
        guard watch.promptCount < maxPrompts else {
            store.clear()
            return nil
        }
        if await isWatched(watch.tmdbId) {
            store.clear()
            return nil
        }
        watch.promptCount += 1
        store.record(watch)
        return watch
    }

    /// "Not yet": keep it and ask again after `snoozeInterval`.
    func snooze() {
        guard var watch = store.load() else { return }
        watch.snoozedUntil = store.now().addingTimeInterval(snoozeInterval)
        store.record(watch)
    }

    /// "Yes" or "No": stop asking.
    func resolve() {
        store.clear()
    }

    #if DEBUG
    /// `-pendingWatchDemo <tmdbId> [-pendingWatchDemoTitle <title>]` seeds a
    /// pending watch past the threshold so the prompt shows on launch.
    static func seedDemoIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) {
        func value(_ flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        guard let id = value("-pendingWatchDemo").flatMap(Int.init) else { return }
        let store = PendingWatchStore()
        store.record(PendingWatch(
            tmdbId: id,
            title: value("-pendingWatchDemoTitle") ?? "this movie",
            posterPath: nil,
            openedAt: store.now().addingTimeInterval(-3600)
        ))
    }
    #endif
}

extension WhereToWatch {
    /// Stream, then rent, then buy. Each group is already deduped by provider.
    var hubOffers: [(kind: WatchOfferKind, offer: WatchOffer)] {
        WatchOfferKind.allCases.flatMap { kind in offers(kind).map { (kind: kind, offer: $0) } }
    }

    /// Collapsed Where to Watch: one row per provider (stream first, then rent, then buy,
    /// each in JustWatch's relevance order). Up to `limit` rows; a list of at most
    /// `limit + 1` shows in full so "More" never hides a single row.
    func watchList(
        limit: Int = 4,
        expanded: Bool = false
    ) -> (visible: [(kind: WatchOfferKind, offer: WatchOffer)], hiddenCount: Int) {
        var seen: Set<Int> = []
        let unique = hubOffers.filter { seen.insert($0.offer.providerId).inserted }
        if expanded || unique.count <= limit + 1 { return (unique, 0) }
        return (Array(unique.prefix(limit)), unique.count - limit)
    }

    /// The first offers by hub order, one per provider.
    func topProviders(limit: Int) -> [WatchOffer] {
        var seen: Set<Int> = []
        return Array(hubOffers.map(\.offer).filter { seen.insert($0.providerId).inserted }.prefix(limit))
    }
}

/// Where-to-watch per title for list rows. Caches hits, shares in-flight
/// requests, and caps concurrent fetches so a scrolling list can't storm the API.
actor WatchProviderCache {
    typealias Fetch = @Sendable (Int, MediaType) async throws -> WhereToWatch?

    static let shared = WatchProviderCache(maxConcurrent: 3) { id, type in
        try await MoviesAPI.getStreaming(tmdbId: id, mediaType: type).whereToWatch
    }

    private let maxConcurrent: Int
    private let fetch: Fetch
    private var results: [String: WhereToWatch?] = [:]
    private var inFlight: [String: Task<WhereToWatch??, Never>] = [:]
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrent: Int, fetch: @escaping Fetch) {
        self.maxConcurrent = maxConcurrent
        self.fetch = fetch
    }

    /// nil when the title has no data or the request failed. Failures aren't cached.
    func whereToWatch(tmdbId: Int, mediaType: MediaType) async -> WhereToWatch? {
        let key = "\(mediaType.rawValue)-\(tmdbId)"
        if let hit = results[key] { return hit }
        let task = inFlight[key] ?? Task {
            await acquire()
            defer { release() }
            do {
                return try await .some(fetch(tmdbId, mediaType))
            } catch {
                return .none
            }
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result { results[key] = result }
        return result ?? nil
    }

    private func acquire() async {
        if running < maxConcurrent {
            running += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty {
            running -= 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}
