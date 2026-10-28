import Foundation

/// Where a reel trailer plays from. Never a scraped YouTube stream: licensed iTunes
/// previews play natively, otherwise the official YouTube embed, otherwise nothing.
enum TrailerSourceKind: Equatable {
    case native(URL)
    case youtube(String)
    case unavailable
}

/// Looks up an iTunes Search API `previewUrl` once per movie. Hits and misses are
/// cached in memory and UserDefaults for 7 days; network errors are not cached.
final class TrailerSource {
    static let shared = TrailerSource()
    static let ttl: TimeInterval = 7 * 86400

    private let fetch: (URL) async throws -> Data
    private let defaults: UserDefaults
    private let now: () -> Date
    private var memory: [Int: (url: URL?, at: Double)] = [:]

    init(
        fetch: @escaping (URL) async throws -> Data = { url in
            var request = URLRequest(url: url)
            request.timeoutInterval = 4
            return try await URLSession.shared.data(for: request).0
        },
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.fetch = fetch
        self.defaults = defaults
        self.now = now
    }

    func resolve(tmdbId: Int, title: String, year: Int?, trailerUrl: String?) async -> TrailerSourceKind {
        if let url = await nativeClipURL(tmdbId: tmdbId, title: title, year: year) {
            return .native(url)
        }
        if let id = trailerUrl.flatMap(YouTubePlayerView.extractVideoId(from:)) {
            return .youtube(id)
        }
        return .unavailable
    }

    func nativeClipURL(tmdbId: Int, title: String, year: Int?) async -> URL? {
        let clock = now().timeIntervalSince1970
        if let cached = memory[tmdbId], clock - cached.at < Self.ttl { return cached.url }
        let key = "trailerSource.\(tmdbId)"
        let stored = defaults.dictionary(forKey: key)
        if let savedAt = stored?["at"] as? Double, clock - savedAt < Self.ttl, let stored {
            let url = (stored["url"] as? String).flatMap(URL.init(string:))
            memory[tmdbId] = (url, savedAt)
            return url
        }
        guard let search = Self.searchURL(title: title),
              let data = try? await fetch(search),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = json["results"] as? [[String: Any]]
        else { return nil }
        let url = Self.match(rows, title: title, year: year)
        memory[tmdbId] = (url, clock)
        var entry: [String: Any] = ["at": clock]
        entry["url"] = url?.absoluteString
        defaults.set(entry, forKey: key)
        return url
    }

    static func searchURL(title: String) -> URL? {
        var parts = URLComponents(string: "https://itunes.apple.com/search")
        parts?.queryItems = [
            URLQueryItem(name: "term", value: title),
            URLQueryItem(name: "media", value: "movie"),
            URLQueryItem(name: "entity", value: "movie"),
            URLQueryItem(name: "limit", value: "10"),
        ]
        return parts?.url
    }

    /// First feature film whose normalized title equals ours and whose year is within ±1.
    static func match(_ rows: [[String: Any]], title: String, year: Int?) -> URL? {
        let wanted = normalize(title)
        for row in rows {
            guard row["kind"] as? String == "feature-movie",
                  let name = row["trackName"] as? String, normalize(name) == wanted,
                  let preview = row["previewUrl"] as? String, let url = URL(string: preview)
            else { continue }
            if let year {
                guard let release = (row["releaseDate"] as? String)?.prefix(4),
                      let releaseYear = Int(release), abs(releaseYear - year) <= 1
                else { continue }
            }
            return url
        }
        return nil
    }

    static func normalize(_ title: String) -> String {
        title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Official embed parameters: no controls, no branding, inline, muted.
enum YouTubeEmbed {
    static let host = "https://www.youtube-nocookie.com"

    static let playerVars: [URLQueryItem] = [
        URLQueryItem(name: "controls", value: "0"),
        URLQueryItem(name: "modestbranding", value: "1"),
        URLQueryItem(name: "playsinline", value: "1"),
        URLQueryItem(name: "rel", value: "0"),
        URLQueryItem(name: "iv_load_policy", value: "3"),
        URLQueryItem(name: "fs", value: "0"),
        URLQueryItem(name: "disablekb", value: "1"),
        URLQueryItem(name: "mute", value: "1"),
        URLQueryItem(name: "autoplay", value: "1"),
    ]

    static func url(videoId: String) -> URL? {
        var parts = URLComponents(string: "\(host)/embed/\(videoId)")
        parts?.queryItems = playerVars
        return parts?.url
    }

    /// `playerVars` as a JS object literal for `YT.Player`.
    static var playerVarsJS: String {
        let pairs = playerVars.map { "\($0.name): \($0.value ?? "0")" }
        return "{ \(pairs.joined(separator: ", ")), origin: '\(host)' }"
    }
}

/// Only the next reel is warmed up, and nothing in Low Power Mode.
enum TrailerPreloadPolicy {
    static func target(after currentId: Int, in ids: [Int], lowPower: Bool) -> Int? {
        guard !lowPower, let idx = ids.firstIndex(of: currentId), idx + 1 < ids.count else { return nil }
        return ids[idx + 1]
    }
}

/// Press-and-hold plays, a 1s hold locks playback on, a tap stops a locked trailer
/// or toggles the info overlay.
/// Tap a poster to play its trailer with every overlay hidden; tap again, or let it end, to go back.
struct TrailerPlaybackState: Equatable {
    enum Event { case tapped, ended, stopped }
    enum Effect: Equatable { case ignore, play, stop }

    private(set) var isPlaying = false

    var showsOverlay: Bool {
        !isPlaying
    }

    mutating func send(_ event: Event) -> Effect {
        switch (event, isPlaying) {
        case (.tapped, false):
            isPlaying = true
            return .play
        case (.tapped, true), (.ended, true), (.stopped, true):
            isPlaying = false
            return .stop
        default:
            return .ignore
        }
    }
}
