import Foundation

/// The "Find a movie for us" pick: first rec is the pick, "Another pick" walks the list (no extra request).
struct BlendPickDeck {
    let movies: [GroupRecMovieResponse]
    private(set) var index = 0

    var current: GroupRecMovieResponse? {
        movies.isEmpty ? nil : movies[index]
    }

    mutating func next() {
        guard !movies.isEmpty else { return }
        index = (index + 1) % movies.count
    }
}

@MainActor @Observable
final class BlendPickModel {
    enum Phase: Equatable {
        case loading, ready, empty
        case failed(UserFacingError)
    }

    private(set) var phase: Phase = .loading
    private(set) var deck = BlendPickDeck(movies: [])
    private let fetch: () async throws -> [GroupRecMovieResponse]

    init(fetch: @escaping () async throws -> [GroupRecMovieResponse]) {
        self.fetch = fetch
    }

    convenience init(groupId: Int) {
        self.init { try await GroupsAPI.getRecommendations(groupId: groupId).results }
    }

    func load() async {
        phase = .loading
        do {
            deck = try await BlendPickDeck(movies: fetch())
            phase = deck.current == nil ? .empty : .ready
        } catch {
            phase = .failed(UserFacingError.capture(error, screen: "BlendPick"))
        }
    }

    func anotherPick() {
        deck.next()
    }
}

/// Invite helpers for adding blend members by username.
enum BlendInvite {
    struct Candidate: Identifiable, Equatable {
        let id: String
        let username: String
        let displayName: String?
        let avatarUrl: String?
        let isFriend: Bool
    }

    static func shareText(username: String?) -> String {
        let handle = username?.trimmingCharacters(in: .whitespaces) ?? ""
        return handle.isEmpty ? "Join my blnd blend" : "Join my blnd blend — add me: @\(handle)"
    }

    /// Friends matching the query first, then other users from search; members/self excluded.
    static func candidates(
        friends: [FriendResponse],
        searchResults: [UserSearchResult],
        query: String,
        excluding: Set<String>
    ) -> [Candidate] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        let matchingFriends = friends.filter {
            trimmed.isEmpty
                || $0.username.lowercased().contains(trimmed)
                || ($0.displayName?.lowercased().contains(trimmed) ?? false)
        }
        var seen = excluding
        var result: [Candidate] = []
        for friend in matchingFriends where seen.insert(friend.id).inserted {
            result.append(Candidate(
                id: friend.id, username: friend.username, displayName: friend.displayName,
                avatarUrl: friend.avatarUrl, isFriend: true
            ))
        }
        guard !trimmed.isEmpty else { return result }
        for user in searchResults where seen.insert(user.id).inserted {
            result.append(Candidate(
                id: user.id, username: user.username, displayName: user.displayName,
                avatarUrl: user.avatarUrl, isFriend: false
            ))
        }
        return result
    }
}
