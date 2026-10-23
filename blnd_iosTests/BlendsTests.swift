@testable import blnd_ios
import Foundation
import Testing

private func recJSON(_ id: Int, reason: String? = nil, includeReasonKey: Bool = true) -> String {
    let reasonField: String
    if !includeReasonKey {
        reasonField = ""
    } else if let reason {
        reasonField = #","reason":"\#(reason)""#
    } else {
        reasonField = #","reason":null"#
    }
    return """
    {"tmdb_id":\(id),"title":"Movie \(id)","year":2020,"overview":null,"poster_path":"/p\(id).jpg",
     "genres":[],"runtime":100,"vote_average":7.1,"trailer_url":null,"director":null,"cast":[],
     "tagline":null,"backdrop_path":null,"match_score":0.87,"comment_count":0,"media_type":"movie"\(reasonField)}
    """
}

private func decodeRecs(_ items: [String]) throws -> [GroupRecMovieResponse] {
    let json = Data(#"{"results":[\#(items.joined(separator: ","))]}"#.utf8)
    return try JSONDecoder().decode(GroupRecommendationsResponse.self, from: json).results
}

private func friend(_ id: String, _ username: String) -> FriendResponse {
    FriendResponse(friendshipId: 1, id: id, username: username, displayName: nil, avatarUrl: nil)
}

private func searchUser(_ id: String, _ username: String) -> UserSearchResult {
    UserSearchResult(
        id: id, username: username, displayName: nil, avatarUrl: nil,
        friendshipStatus: nil, friendshipId: nil
    )
}

struct BlendReasonDecodingTests {
    @Test func reasonPresent() throws {
        let recs = try decodeRecs([recJSON(1, reason: "You both rated Heat highly")])
        #expect(recs[0].reason == "You both rated Heat highly")
    }

    @Test func reasonNull() throws {
        let recs = try decodeRecs([recJSON(1, reason: nil)])
        #expect(recs[0].reason == nil)
    }

    @Test func reasonMissing() throws {
        let recs = try decodeRecs([recJSON(1, includeReasonKey: false)])
        #expect(recs[0].reason == nil)
        #expect(recs[0].scorePercent == 87)
    }
}

struct BlendPickDeckTests {
    @Test func firstItemIsThePick() throws {
        let deck = try BlendPickDeck(movies: decodeRecs([recJSON(10), recJSON(20)]))
        #expect(deck.current?.tmdbId == 10)
    }

    @Test func anotherPickCyclesAndWraps() throws {
        var deck = try BlendPickDeck(movies: decodeRecs([recJSON(10), recJSON(20), recJSON(30)]))
        deck.next()
        #expect(deck.current?.tmdbId == 20)
        deck.next()
        #expect(deck.current?.tmdbId == 30)
        deck.next()
        #expect(deck.current?.tmdbId == 10)
    }

    @Test func emptyDeckHasNoPick() {
        var deck = BlendPickDeck(movies: [])
        deck.next()
        #expect(deck.current == nil)
    }
}

@MainActor
struct BlendPickModelTests {
    @Test func loadUsesInjectedFetchOnceAndShowsFirst() async throws {
        let recs = try decodeRecs([recJSON(10), recJSON(20)])
        var calls = 0
        let model = BlendPickModel {
            calls += 1
            return recs
        }
        await model.load()
        #expect(model.phase == .ready)
        #expect(model.deck.current?.tmdbId == 10)
        model.anotherPick()
        #expect(model.deck.current?.tmdbId == 20)
        #expect(calls == 1)
    }

    @Test func noResultsIsEmptyState() async {
        let model = BlendPickModel { [] }
        await model.load()
        #expect(model.phase == .empty)
    }

    @Test func fetchFailureIsErrorState() async {
        let model = BlendPickModel { throw URLError(.notConnectedToInternet) }
        await model.load()
        guard case .failed = model.phase else {
            Issue.record("expected failed, got \(model.phase)")
            return
        }
    }
}

struct BlendInviteTests {
    @Test func shareTextUsesUsername() {
        #expect(BlendInvite.shareText(username: "jon") == "Join my blnd blend — add me: @jon")
    }

    @Test func shareTextWithoutUsernameDropsHandle() {
        #expect(BlendInvite.shareText(username: nil) == "Join my blnd blend")
        #expect(BlendInvite.shareText(username: "  ") == "Join my blnd blend")
    }

    @Test func candidatesListFriendsFirstThenOthersWithoutDuplicates() {
        let friends = [friend("f1", "alice"), friend("f2", "bob")]
        let search = [searchUser("u9", "alfred"), searchUser("f1", "alice"), searchUser("me", "alan")]
        let result = BlendInvite.candidates(
            friends: friends, searchResults: search, query: "al", excluding: ["me"]
        )
        #expect(result.map(\.username) == ["alice", "alfred"])
        #expect(result.map(\.isFriend) == [true, false])
    }

    @Test func emptyQueryShowsAllFriendsOnly() {
        let friends = [friend("f1", "alice"), friend("f2", "bob")]
        let result = BlendInvite.candidates(
            friends: friends, searchResults: [searchUser("u9", "zed")], query: " ", excluding: ["f2"]
        )
        #expect(result.map(\.username) == ["alice"])
    }
}
