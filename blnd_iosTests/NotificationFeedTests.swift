@testable import blnd_ios
import Foundation
import Testing

struct NotificationFeedTests {
    @Test func aggregatesLikesAsSamAndThreeOthers() {
        let now = Date()
        let feed = ActivityPreview.sample(now: now)
        let today = feed.sections.first { $0.bucket == .today }
        let likes = today?.rows.first { $0.lineLead == "Sam and 3 others" }

        #expect(feed.requests.map(\.name) == ["Maya"])
        #expect(today?.rows.contains { $0.lineLead == "Alex" } == true)
        #expect(likes?.lineRest == " liked your comment on Past Lives")
        #expect(likes?.isUnread == true)
        #expect(likes?.posterURL?.absoluteString.contains("k3waqVXSnvCZWfJYNtdamTgTtTA") == true)
        #expect(likes?.route == .comments(tmdbId: 666277, title: "Past Lives"))
    }

    @Test func groupsTodayThisWeekAndEarlier() {
        let now = Date()
        let feed = ActivityPreview.sample(now: now)
        let buckets = feed.sections.map(\.bucket)

        #expect(buckets == [.today, .thisWeek, .earlier])
        #expect(feed.sections[0].rows.contains { $0.lineLead == "Priya" })
        #expect(feed.sections[1].rows.contains { $0.lineLead == "Chris" && $0.lineRest.contains("Heat") })
        #expect(feed.sections[2].rows.contains { $0.lineRest.contains("Decision to Leave") })
        #expect(feed.requests.allSatisfy { request in
            !feed.sections.flatMap(\.rows).contains { $0.lineLead == request.name }
        })
    }

    @Test func groupKeyDoesNotMergeDifferentRows() {
        let now = Date()
        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withInternetDateTime]
        let created = stamp.string(from: now)
        func like(id: Int, name: String, key: String) -> InboxItem {
            InboxItem(
                id: id,
                type: "like",
                fromUsername: name,
                fromAvatarUrl: nil,
                groupKey: key,
                target: InboxTarget(type: "comment", id: key),
                title: "like",
                body: "\(name) liked your comment",
                data: ["tmdb_id": "1", "movie_title": "Heat"],
                read: false,
                createdAt: created
            )
        }
        let feed = ActivityFeed.make(
            inbox: [like(id: 1, name: "Sam", key: "like:comment:1"), like(id: 2, name: "Jules", key: "like:comment:2")],
            now: now
        )
        let rows = feed.sections.flatMap(\.rows)
        #expect(rows.count == 2)
        #expect(feed.requests.isEmpty)
    }

    @Test func weekBoundaryUsesRollingSevenDays() {
        let now = Date()
        let calendar = Calendar.current
        let today = now.addingTimeInterval(-60)
        let sixDays = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let eightDays = calendar.date(byAdding: .day, value: -8, to: now) ?? now

        #expect(ActivityFeed.bucket(for: today, now: now) == .today)
        #expect(ActivityFeed.bucket(for: sixDays, now: now) == .thisWeek)
        #expect(ActivityFeed.bucket(for: eightDays, now: now) == .earlier)
    }

    @Test func routesCommentAndBlendTaps() {
        #expect(
            ActivityFeed.deepLink(type: "comment_reply", data: ["tmdb_id": "15"])
                == .comments(tmdbId: 15)
        )
        #expect(
            ActivityFeed.deepLink(type: "group_watchlist", data: ["group_id": "3", "tmdb_id": "9"])
                == .groupDetail(groupId: 3)
        )
        #expect(
            ActivityFeed.deepLink(type: "watched_with", data: ["tmdb_id": "949"])
                == .movieDetail(tmdbId: 949)
        )
        #expect(ActivityFeed.deepLink(type: "new_follower", data: [:]) == .friendRequests)
        #expect(ActivityFeed.deepLink(type: "friend_request", data: [:]) == .friendRequests)
    }

    @Test func serverChannelsAreTheSettings() {
        var push = ChannelPrefs()
        push.friendRatings = false
        var inApp = ChannelPrefs()
        inApp.watchedWith = false
        let server = NotificationPreferences(
            friendRequests: true,
            groupInvites: true,
            recommendations: true,
            friendActivity: true,
            commentReplies: true,
            shareRatings: "off",
            inApp: inApp,
            push: push
        )
        let prefs = NotificationPrivacyPrefs(server: server)
        #expect(prefs.shareRatings == .off)
        #expect(prefs.push.friendRatings == false)
        #expect(prefs.inApp.watchedWith == false)
        #expect(prefs.push.blendActivity == true)
    }

    @Test func decodesPreferenceAndInboxContract() throws {
        let prefsJSON = """
        {"friend_requests":true,"group_invites":true,"recommendations":true,\
        "friend_activity":true,"comment_replies":true,"share_ratings":"friends",\
        "in_app":{"friend_ratings":true,"blend_activity":true,"comments_likes":true,\
        "watched_with":true,"recommendations":true},\
        "push":{"friend_ratings":false,"blend_activity":true,"comments_likes":true,\
        "watched_with":true,"recommendations":true}}
        """
        let prefs = try JSONDecoder().decode(NotificationPreferences.self, from: Data(prefsJSON.utf8))
        #expect(prefs.shareRatings == "friends")
        #expect(prefs.push.friendRatings == false)
        #expect(prefs.inApp.watchedWith == true)

        let legacy = """
        {"friend_requests":true,"group_invites":true,"recommendations":true,\
        "friend_activity":true,"comment_replies":true}
        """
        let legacyPrefs = try? JSONDecoder().decode(NotificationPreferences.self, from: Data(legacy.utf8))
        #expect(legacyPrefs == nil)

        let rowJSON = """
        {"id":5,"type":"like","from_username":"Alex","from_avatar_url":"https://cdn.example/alex.jpg",\
        "avatar_url":"https://cdn.example/alex.jpg","title":"New Like","body":"Alex liked your review",\
        "poster_url":"https://image.tmdb.org/t/p/w185/poster.jpg","group_key":"like:comment:1",\
        "target":{"type":"comment","id":"1"},"data":{"poster_path":"/poster.jpg",\
        "poster_url":"https://image.tmdb.org/t/p/w185/poster.jpg","tmdb_id":"15"},\
        "read":false,"created_at":"2026-10-15T12:00:00Z","actions":[]}
        """
        let row = try JSONDecoder().decode(InboxItem.self, from: Data(rowJSON.utf8))
        #expect(row.groupKey == "like:comment:1")
        #expect(row.target == InboxTarget(type: "comment", id: "1"))
        #expect(row.data?["poster_path"] == "/poster.jpg")
        #expect(row.actions.isEmpty)
        #expect(row.canRespond == false)
    }

    @Test func patchSendsShareRatingsAndChannels() throws {
        let request = NotificationPrivacyPrefs(shareRatings: .off).asRequest()
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        let push = object?["push"] as? [String: Bool]
        #expect(object?["friend_requests"] == nil)
        #expect(object?["share_ratings"] as? String == "off")
        #expect(object?["friend_activity"] as? Bool == true)
        #expect(push?["friend_ratings"] == true)
        #expect(push?["watched_with"] == true)
    }

    @Test func readsErrorEnvelopeMessage() {
        let body = #"{"error":{"code":"VALIDATION_ERROR","message":"Try again"},"detail":"raw"}"#
        #expect(APIErrorEnvelope.message(in: Data(body.utf8)) == "Try again")
    }
}
