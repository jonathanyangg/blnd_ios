@testable import blnd_ios
import Foundation
import Testing

// MARK: - TrailerSource

@MainActor
struct TrailerSourceTests {
    private static func itunes(_ items: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["results": items])
    }

    private static let inception: [String: Any] = [
        "kind": "feature-movie",
        "trackName": "Inception",
        "releaseDate": "2010-07-16T07:00:00Z",
        "previewUrl": "https://video.itunes.apple.com/inception.m4v",
    ]

    private func makeSource(
        data: Data? = nil,
        fails: Bool = false,
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_000_000) },
        calls: Counter = Counter()
    ) -> TrailerSource {
        let defaults = UserDefaults(suiteName: "TrailerSourceTests.\(UUID().uuidString)")!
        return TrailerSource(
            fetch: { _ in
                calls.value += 1
                if fails { throw URLError(.notConnectedToInternet) }
                return data ?? Self.itunes([])
            },
            defaults: defaults,
            now: now
        )
    }

    final class Counter: @unchecked Sendable {
        var value = 0
    }

    @Test func matchesNormalizedTitleAndYearWithinOne() {
        let rows = [Self.inception]
        #expect(TrailerSource.match(rows, title: "inception!", year: 2011)?.absoluteString
            == "https://video.itunes.apple.com/inception.m4v")
        #expect(TrailerSource.match(rows, title: "Inception", year: 2012) == nil)
        #expect(TrailerSource.match(rows, title: "Inception 2", year: 2010) == nil)
    }

    @Test func ignoresNonFeatureMovies() {
        var row = Self.inception
        row["kind"] = "tv-episode"
        #expect(TrailerSource.match([row], title: "Inception", year: 2010) == nil)
    }

    @Test func normalizesDiacriticsAndPunctuation() {
        #expect(TrailerSource.normalize("Amélie: The Movie") == TrailerSource.normalize("amelie the movie"))
    }

    @Test func prefersNativeThenYouTubeThenNone() async throws {
        let found = makeSource(data: Self.itunes([Self.inception]))
        let native = await found.resolve(
            tmdbId: 1,
            title: "Inception",
            year: 2010,
            trailerUrl: "https://youtu.be/abcdefghijk"
        )
        #expect(try native == .native(#require(URL(string: "https://video.itunes.apple.com/inception.m4v"))))

        let missing = makeSource()
        let youtube = await missing.resolve(
            tmdbId: 2,
            title: "Obscure",
            year: 2010,
            trailerUrl: "https://www.youtube.com/watch?v=abcdefghijk"
        )
        #expect(youtube == .youtube("abcdefghijk"))

        let none = await missing.resolve(tmdbId: 3, title: "Obscure", year: 2010, trailerUrl: nil)
        #expect(none == .unavailable)
    }

    @Test func cachesNegativeResultsForSevenDays() async {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let calls = Counter()
        let source = makeSource(now: { clock }, calls: calls)

        _ = await source.nativeClipURL(tmdbId: 9, title: "Obscure", year: 2010)
        _ = await source.nativeClipURL(tmdbId: 9, title: "Obscure", year: 2010)
        #expect(calls.value == 1)

        clock += 6 * 86400
        _ = await source.nativeClipURL(tmdbId: 9, title: "Obscure", year: 2010)
        #expect(calls.value == 1)

        clock += 2 * 86400
        _ = await source.nativeClipURL(tmdbId: 9, title: "Obscure", year: 2010)
        #expect(calls.value == 2)
    }

    @Test func persistsAcrossInstancesViaDefaults() async throws {
        let defaults = try #require(UserDefaults(suiteName: "TrailerSourceTests.\(UUID().uuidString)"))
        let calls = Counter()
        let make = {
            TrailerSource(
                fetch: { _ in calls.value += 1; return Self.itunes([Self.inception]) },
                defaults: defaults,
                now: { Date(timeIntervalSince1970: 1_000_000) }
            )
        }
        _ = await make().nativeClipURL(tmdbId: 5, title: "Inception", year: 2010)
        let url = await make().nativeClipURL(tmdbId: 5, title: "Inception", year: 2010)
        #expect(calls.value == 1)
        #expect(url != nil)
    }

    @Test func networkErrorsAreNotCached() async {
        let calls = Counter()
        let source = makeSource(fails: true, calls: calls)
        _ = await source.nativeClipURL(tmdbId: 7, title: "Inception", year: 2010)
        _ = await source.nativeClipURL(tmdbId: 7, title: "Inception", year: 2010)
        #expect(calls.value == 2)
    }

    @Test func searchURLUsesMovieMedia() throws {
        let url = TrailerSource.searchURL(title: "Mad Max: Fury Road")
        let items = try URLComponents(url: #require(url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(url?.host == "itunes.apple.com")
        #expect(items.contains(URLQueryItem(name: "media", value: "movie")))
        #expect(items.contains(URLQueryItem(name: "term", value: "Mad Max: Fury Road")))
    }
}

// MARK: - Tap-to-play state machine

struct TrailerPlaybackStateTests {
    @Test func tapPlaysAndHidesOverlay() {
        var state = TrailerPlaybackState()
        #expect(state.showsOverlay)
        #expect(state.send(.tapped) == .play)
        #expect(state.isPlaying)
        #expect(!state.showsOverlay)
    }

    @Test func secondTapStopsAndRestoresOverlay() {
        var state = TrailerPlaybackState()
        _ = state.send(.tapped)
        #expect(state.send(.tapped) == .stop)
        #expect(!state.isPlaying)
        #expect(state.showsOverlay)
    }

    @Test func trailerEndingReturnsToPoster() {
        var state = TrailerPlaybackState()
        _ = state.send(.tapped)
        #expect(state.send(.ended) == .stop)
        #expect(state.showsOverlay)
    }

    @Test func strayEventsAreIgnored() {
        var state = TrailerPlaybackState()
        #expect(state.send(.ended) == .ignore)
        #expect(state.send(.stopped) == .ignore)
        #expect(state.showsOverlay)
    }

    @Test func externalStopResetsPlayback() {
        var state = TrailerPlaybackState()
        _ = state.send(.tapped)
        #expect(state.send(.stopped) == .stop)
        #expect(state.send(.stopped) == .ignore)
    }
}

// MARK: - YouTube embed + preload policy

struct YouTubeEmbedTests {
    @Test func paramsHideChromeAndMute() {
        let params = Dictionary(uniqueKeysWithValues: YouTubeEmbed.playerVars.map { ($0.name, $0.value) })
        for (key, value) in [
            "controls": "0", "modestbranding": "1", "playsinline": "1", "rel": "0",
            "iv_load_policy": "3", "fs": "0", "disablekb": "1", "mute": "1",
        ] {
            #expect(params[key] == value, "\(key)")
        }
    }

    @Test func embedURLUsesNoCookieHost() {
        let url = YouTubeEmbed.url(videoId: "abcdefghijk")
        #expect(url?.absoluteString.hasPrefix("https://www.youtube-nocookie.com/embed/abcdefghijk?") == true)
        #expect(url?.query?.contains("mute=1") == true)
    }
}

struct TrailerPreloadPolicyTests {
    @Test func preloadsNextItemOnly() {
        #expect(TrailerPreloadPolicy.target(after: 10, in: [10, 20, 30], lowPower: false) == 20)
        #expect(TrailerPreloadPolicy.target(after: 30, in: [10, 20, 30], lowPower: false) == nil)
        #expect(TrailerPreloadPolicy.target(after: 99, in: [10, 20, 30], lowPower: false) == nil)
    }

    @Test func noPreloadInLowPowerMode() {
        #expect(TrailerPreloadPolicy.target(after: 10, in: [10, 20, 30], lowPower: true) == nil)
    }
}
