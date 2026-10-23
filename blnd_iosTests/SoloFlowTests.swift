@testable import blnd_ios
import Foundation
import Testing

/// A clock the tests move by hand.
private final class TestClock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

@MainActor
struct PendingWatchStoreTests {
    private let clock = TestClock()

    private func makeStore() -> PendingWatchStore {
        let name = "SoloFlowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return PendingWatchStore(defaults: defaults, now: { [clock] in clock.now })
    }

    private func watch(_ id: Int, at date: Date) -> PendingWatch {
        PendingWatch(tmdbId: id, title: "Movie \(id)", posterPath: "/p\(id).jpg", openedAt: date)
    }

    @Test func recordsAndLoads() {
        let store = makeStore()
        store.record(watch(550, at: clock.now))
        #expect(store.load() == watch(550, at: clock.now))
    }

    @Test func keepsNewestOnly() {
        let store = makeStore()
        store.record(watch(550, at: clock.now))
        clock.advance(60)
        store.record(watch(27205, at: clock.now))
        #expect(store.load()?.tmdbId == 27205)
    }

    @Test func expiresAfterTwelveHours() {
        let store = makeStore()
        store.record(watch(550, at: clock.now))
        clock.advance(12 * 3600 - 1)
        #expect(store.load() != nil)
        clock.advance(2)
        #expect(store.load() == nil)
        // Expired entries are removed, not just hidden.
        clock.now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(store.load() == nil)
    }

    @Test func clears() {
        let store = makeStore()
        store.record(watch(550, at: clock.now))
        store.clear()
        #expect(store.load() == nil)
    }
}

@MainActor
struct PostWatchPromptTests {
    private let clock = TestClock()

    private func makePrompt() -> PostWatchPrompt {
        let name = "SoloFlowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let store = PendingWatchStore(defaults: defaults, now: { [clock] in clock.now })
        store.record(PendingWatch(tmdbId: 550, title: "Fight Club", posterPath: nil, openedAt: clock.now))
        return PostWatchPrompt(store: store)
    }

    private let notWatched: (Int) async -> Bool = { _ in false }

    @Test func waitsForMinElapsed() async {
        let prompt = makePrompt()
        clock.advance(19 * 60)
        #expect(await prompt.next(isWatched: notWatched) == nil)
        clock.advance(60)
        #expect(await prompt.next(isWatched: notWatched)?.tmdbId == 550)
    }

    @Test func minElapsedIsInjectable() async {
        var prompt = makePrompt()
        prompt.minElapsed = 60
        clock.advance(61)
        #expect(await prompt.next(isWatched: notWatched) != nil)
    }

    @Test func snoozeRepromptsAfterTwoHours() async {
        let prompt = makePrompt()
        clock.advance(30 * 60)
        #expect(await prompt.next(isWatched: notWatched) != nil)
        prompt.snooze()
        clock.advance(2 * 3600 - 1)
        #expect(await prompt.next(isWatched: notWatched) == nil)
        clock.advance(2)
        #expect(await prompt.next(isWatched: notWatched) != nil)
    }

    @Test func stopsAfterTwoPrompts() async {
        let prompt = makePrompt()
        clock.advance(30 * 60)
        #expect(await prompt.next(isWatched: notWatched) != nil)
        prompt.snooze()
        clock.advance(2 * 3600)
        #expect(await prompt.next(isWatched: notWatched) != nil)
        prompt.snooze()
        clock.advance(2 * 3600)
        #expect(await prompt.next(isWatched: notWatched) == nil)
        #expect(prompt.store.load() == nil)
    }

    @Test func neverPromptsForAlreadyWatched() async {
        let prompt = makePrompt()
        clock.advance(30 * 60)
        #expect(await prompt.next(isWatched: { $0 == 550 }) == nil)
        #expect(prompt.store.load() == nil)
    }

    @Test func noAndYesClear() async {
        let prompt = makePrompt()
        clock.advance(30 * 60)
        #expect(await prompt.next(isWatched: notWatched) != nil)
        prompt.resolve()
        #expect(await prompt.next(isWatched: notWatched) == nil)
    }

    @Test func expiredWatchNeverPrompts() async {
        let prompt = makePrompt()
        clock.advance(13 * 3600)
        #expect(await prompt.next(isWatched: notWatched) == nil)
    }
}

@MainActor
struct WatchHubTests {
    private func offer(_ id: Int, _ name: String) -> WatchOffer {
        WatchOffer(
            providerId: id,
            providerName: name,
            logoPath: "/\(id).jpg",
            webUrl: "https://example.com/\(id)",
            appUrl: nil,
            clickUrl: nil,
            iosLink: nil
        )
    }

    private var payload: WhereToWatch {
        WhereToWatch(
            country: "US",
            attribution: "JustWatch",
            link: nil,
            flatrate: [offer(8, "Netflix"), offer(8, "Netflix")],
            rent: [offer(2, "Apple TV"), offer(3, "Google Play")],
            buy: [offer(2, "Apple TV"), offer(10, "Amazon")]
        )
    }

    @Test func hubOrdersStreamThenRentThenBuyAndDedupesWithinGroup() {
        let hub = payload.hubOffers.map { "\($0.kind.rawValue):\($0.offer.providerId)" }
        #expect(hub == ["watchNow:8", "rent:2", "rent:3", "buy:2", "buy:10"])
    }

    @Test func topProvidersDedupeAcrossGroups() {
        #expect(payload.topProviders(limit: 3).map(\.providerId) == [8, 2, 3])
        #expect(payload.topProviders(limit: 10).map(\.providerId) == [8, 2, 3, 10])
    }
}

struct WatchProviderCacheTests {
    private actor Probe {
        var calls: [Int] = []
        var running = 0
        var peak = 0
        func start(_ id: Int) {
            calls.append(id)
            running += 1
            peak = max(peak, running)
        }

        func end() {
            running -= 1
        }
    }

    @Test func dedupesAndCapsConcurrency() async {
        let probe = Probe()
        let cache = WatchProviderCache(maxConcurrent: 2) { id, _ in
            await probe.start(id)
            try await Task.sleep(for: .milliseconds(20))
            await probe.end()
            return nil
        }
        await withTaskGroup(of: Void.self) { group in
            for id in [1, 1, 2, 3, 4, 5] {
                group.addTask { _ = await cache.whereToWatch(tmdbId: id, mediaType: .movie) }
            }
        }
        _ = await cache.whereToWatch(tmdbId: 1, mediaType: .movie)
        #expect(await probe.calls.sorted() == [1, 2, 3, 4, 5])
        #expect(await probe.peak <= 2)
    }

    @Test func failuresAreNotCached() async {
        let probe = Probe()
        let cache = WatchProviderCache(maxConcurrent: 2) { id, _ in
            await probe.start(id)
            await probe.end()
            throw URLError(.notConnectedToInternet)
        }
        _ = await cache.whereToWatch(tmdbId: 1, mediaType: .movie)
        _ = await cache.whereToWatch(tmdbId: 1, mediaType: .movie)
        #expect(await probe.calls == [1, 1])
    }
}
