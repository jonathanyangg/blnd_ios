import Foundation

/// In-memory cache of user watch/rate/watchlist actions.
/// Avoids redundant API calls during a session.
@Observable
final class UserActionCache {
    static let shared = UserActionCache()

    /// tmdbId → rating (nil if watched but unrated)
    private(set) var ratings: [Int: Double?] = [:]

    /// tmdbIds the user has added to personal watchlist
    private(set) var watchlistedIds: Set<Int> = []

    /// Cached groups list (rarely changes within a session)
    private(set) var groups: [GroupResponse] = []
    private(set) var didLoadGroups = false

    /// Whether initial data has been loaded
    private(set) var didLoadInitial = false

    private init() {}

    // MARK: - Bootstrap

    /// Load existing watch history + watchlist on login.
    func bootstrap() async {
        guard !didLoadInitial else { return }
        async let watched: Void = loadWatched()
        async let list: Void = loadWatchlist()
        _ = await (watched, list)
        didLoadInitial = true
    }

    private func loadWatched() async {
        do {
            let response = try await TrackingAPI
                .getWatchHistory(limit: 500)
            for movie in response.results {
                ratings[movie.tmdbId] = movie.rating
            }
        } catch {
            // Non-fatal — cache starts empty
        }
    }

    private func loadWatchlist() async {
        do {
            let response = try await TrackingAPI
                .getWatchlist(limit: 500)
            for movie in response.results {
                watchlistedIds.insert(movie.tmdbId)
            }
        } catch {
            // Non-fatal
        }
    }

    /// Fetch groups list (cached after first call).
    func fetchGroups() async -> [GroupResponse] {
        if didLoadGroups { return groups }
        do {
            let response = try await GroupsAPI.listGroups()
            groups = response.groups
            didLoadGroups = true
        } catch {
            // Non-fatal
        }
        return groups
    }

    func invalidateGroups() {
        didLoadGroups = false
    }

    // MARK: - Queries

    func isWatched(_ tmdbId: Int) -> Bool {
        ratings.keys.contains(tmdbId)
    }

    func rating(for tmdbId: Int) -> Double? {
        ratings[tmdbId] ?? nil
    }

    func isWatchlisted(_ tmdbId: Int) -> Bool {
        watchlistedIds.contains(tmdbId)
    }

    // MARK: - Mutations

    func didRate(_ tmdbId: Int, rating: Double) {
        ratings[tmdbId] = rating
    }

    func didWatchlist(_ tmdbId: Int) {
        watchlistedIds.insert(tmdbId)
    }

    func didRemoveFromWatchlist(_ tmdbId: Int) {
        watchlistedIds.remove(tmdbId)
    }

    func didUnwatch(_ tmdbId: Int) {
        ratings.removeValue(forKey: tmdbId)
    }

    /// Clear on logout.
    func reset() {
        ratings.removeAll()
        watchlistedIds.removeAll()
        groups.removeAll()
        didLoadGroups = false
        didLoadInitial = false
    }
}
