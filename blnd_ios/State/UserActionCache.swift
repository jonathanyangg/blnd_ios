import Foundation

/// In-memory cache of user watch/rate/watchlist actions.
/// Avoids redundant API calls during a session.
@MainActor
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

    /// Cached friends data
    private(set) var friends: [FriendResponse] = []
    private(set) var pendingRequests: PendingRequestsResponse?
    private(set) var didLoadFriends = false

    /// Cache of friends-who-watched per movie. NSCache caps size and purges
    /// automatically on memory warnings — no manual observer required.
    private let friendsWhoWatchedCache: NSCache<NSNumber, ArrayBox<FriendWatchedResponse>> = {
        let cache = NSCache<NSNumber, ArrayBox<FriendWatchedResponse>>()
        cache.countLimit = 150
        return cache
    }()

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

    /// Fetch friends + pending requests (cached after first call).
    func fetchFriends(forceRefresh: Bool = false) async {
        if didLoadFriends, !forceRefresh { return }
        do {
            async let friendsResult = FriendsAPI.listFriends()
            async let requestsResult = FriendsAPI.getPendingRequests()
            let (fData, rData) = try await (friendsResult, requestsResult)
            friends = fData.friends
            pendingRequests = rData
            didLoadFriends = true
        } catch {
            // Non-fatal
        }
    }

    func invalidateFriends() {
        didLoadFriends = false
    }

    func cacheFriendsWhoWatched(_ tmdbId: Int, friends: [FriendWatchedResponse]) {
        friendsWhoWatchedCache.setObject(
            ArrayBox(friends),
            forKey: NSNumber(value: tmdbId)
        )
    }

    func getFriendsWhoWatched(_ tmdbId: Int) -> [FriendWatchedResponse]? {
        friendsWhoWatchedCache
            .object(forKey: NSNumber(value: tmdbId))?
            .values
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

    /// Mark a movie as watched without a rating.
    func didWatch(_ tmdbId: Int) {
        ratings[tmdbId] = nil as Double?
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
        friends.removeAll()
        pendingRequests = nil
        didLoadFriends = false
        friendsWhoWatchedCache.removeAllObjects()
        didLoadInitial = false
    }
}

// MARK: - ArrayBox

/// NSCache only accepts AnyObject values, so Swift arrays need a reference-type wrapper.
private final class ArrayBox<Element> {
    let values: [Element]
    init(_ values: [Element]) {
        self.values = values
    }
}
