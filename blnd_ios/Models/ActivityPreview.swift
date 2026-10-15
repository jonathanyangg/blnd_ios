import Foundation

/// Fixed activity used by the simulator screenshot launch (`-UITestScreen`).
enum ActivityPreview {
    static func sample(now: Date = Date()) -> ActivityFeedContent {
        ActivityFeed.make(
            inbox: items(now: now),
            incoming: [maya(now: now)],
            useInboxFriendRequests: false,
            filter: ChannelPrefs(),
            now: now
        )
    }

    private static func maya(now: Date) -> FriendRequestResponse {
        FriendRequestResponse(
            id: 7,
            requester: FriendResponse(
                friendshipId: 7,
                id: "user-maya",
                username: "maya",
                displayName: "Maya",
                avatarUrl: nil
            ),
            addressee: FriendResponse(
                friendshipId: 7,
                id: "me",
                username: "me",
                displayName: nil,
                avatarUrl: nil
            ),
            status: "pending",
            createdAt: stamp(now.addingTimeInterval(-1_800))
        )
    }

    static func inbox(now: Date = Date()) -> [InboxItem] {
        items(now: now)
    }

    private static func items(now: Date) -> [InboxItem] {
        [
            follow(now: now),
            like(id: 1, name: "Sam", minutesAgo: 20, read: false, now: now),
            like(id: 2, name: "Jules", minutesAgo: 40, read: false, now: now),
            like(id: 3, name: "Noa", minutesAgo: 55, read: true, now: now),
            like(id: 4, name: "Ren", minutesAgo: 70, read: true, now: now),
            invite(now: now),
            comment(now: now),
            watchedWith(now: now),
            match(now: now),
            blendActivity(now: now),
            rating(now: now),
            recommendation(now: now),
        ]
    }

    private static func follow(now: Date) -> InboxItem {
        item(
            id: 11,
            type: "follow_request",
            name: "Alex",
            body: "Alex requested to follow you",
            data: ["type": "follow_request", "user_id": "user-alex", "follow_id": "4"],
            read: false,
            date: now.addingTimeInterval(-600)
        )
    }

    private static func like(id: Int, name: String, minutesAgo: Int, read: Bool, now: Date) -> InboxItem {
        item(
            id: id,
            type: "like",
            name: name,
            body: "\(name) liked your comment on Past Lives",
            data: [
                "type": "like",
                "tmdb_id": "666277",
                "comment_id": "88",
                "movie_title": "Past Lives",
                "poster_path": "/k3waqVXSnvCZWfJYNtdamTgTtTA.jpg",
            ],
            read: read,
            date: now.addingTimeInterval(TimeInterval(-minutesAgo * 60))
        )
    }

    private static func invite(now: Date) -> InboxItem {
        item(
            id: 21,
            type: "group_invite",
            name: "Priya",
            body: "Priya added you to Sunday Sci-Fi",
            data: ["type": "group_invite", "group_id": "3", "group_name": "Sunday Sci-Fi", "user_id": "user-priya"],
            read: false,
            date: now.addingTimeInterval(-7_200)
        )
    }

    private static func comment(now: Date) -> InboxItem {
        item(
            id: 22,
            type: "comment_reply",
            name: "Leo",
            body: "Leo replied to your comment on The Worst Person in the World",
            data: [
                "type": "comment_reply",
                "tmdb_id": "580175",
                "comment_id": "12",
                "movie_title": "The Worst Person in the World",
                "poster_path": "/v4RDkRZqC2N0y2uA7jY4vD6o0nR.jpg",
            ],
            read: false,
            date: now.addingTimeInterval(-18_000)
        )
    }

    private static func watchedWith(now: Date) -> InboxItem {
        item(
            id: 31,
            type: "watched_with",
            name: "Chris",
            body: "Chris tagged you as watched with on Heat",
            data: [
                "type": "watched_with",
                "tmdb_id": "949",
                "movie_title": "Heat",
                "poster_path": "/obpPQskaVpSiC9gVOzvQ1j6L3nA.jpg",
                "user_id": "user-chris",
            ],
            read: true,
            date: now.addingTimeInterval(-2 * 86_400)
        )
    }

    private static func match(now: Date) -> InboxItem {
        item(
            id: 32,
            type: "new_match",
            name: "Dana",
            body: "Dana is a new match on Portrait of a Lady on Fire",
            data: [
                "type": "new_match",
                "tmdb_id": "531428",
                "movie_title": "Portrait of a Lady on Fire",
                "poster_path": "/2j2n2eYwN2n2eYwN2n2eYwN2n2.jpg",
                "user_id": "user-dana",
            ],
            read: false,
            date: now.addingTimeInterval(-3 * 86_400)
        )
    }

    private static func blendActivity(now: Date) -> InboxItem {
        item(
            id: 33,
            type: "group_watchlist",
            name: "Omar",
            body: "Omar added Aftersun to the watchlist",
            data: [
                "type": "group_watchlist",
                "group_id": "3",
                "tmdb_id": "545611",
                "movie_title": "Aftersun",
                "poster_path": "/yNF9t3n0n0n0n0n0n0n0n0n0n0.jpg",
                "user_id": "user-omar",
            ],
            read: true,
            date: now.addingTimeInterval(-4 * 86_400)
        )
    }

    private static func rating(now: Date) -> InboxItem {
        item(
            id: 34,
            type: "friend_activity",
            name: "Ken",
            body: "Ken rated Heat ★ 5",
            data: [
                "type": "friend_activity",
                "tmdb_id": "949",
                "movie_title": "Heat",
                "poster_path": "/obpPQskaVpSiC9gVOzvQ1j6L3nA.jpg",
                "user_id": "user-ken",
            ],
            read: true,
            date: now.addingTimeInterval(-5 * 86_400)
        )
    }

    private static func recommendation(now: Date) -> InboxItem {
        item(
            id: 41,
            type: "weekly_digest",
            name: "blnd",
            body: "blnd recommended Decision to Leave",
            data: [
                "type": "weekly_digest",
                "tmdb_id": "774752",
                "movie_title": "Decision to Leave",
                "poster_path": "/N0n2eYwN2n2eYwN2n2eYwN2n2e.jpg",
            ],
            read: true,
            date: now.addingTimeInterval(-20 * 86_400)
        )
    }

    private static func item(
        id: Int,
        type: String,
        name: String,
        body: String,
        data: [String: String],
        read: Bool,
        date: Date
    ) -> InboxItem {
        InboxItem(
            id: id,
            type: type,
            fromUsername: name,
            fromAvatarUrl: nil,
            title: type,
            body: body,
            data: data,
            read: read,
            createdAt: stamp(date)
        )
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
