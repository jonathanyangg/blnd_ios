@testable import blnd_ios
import Foundation
import Testing

struct NotificationFeedTests {
    @Test func aggregatesLikesAsSamAndThreeOthers() {
        let now = Date()
        let feed = ActivityPreview.sample(now: now)
        let today = feed.sections.first { $0.bucket == .today }
        let likes = today?.rows.first { $0.lineLead == "Sam and 3 others" }

        #expect(feed.requests.map(\.name) == ["Alex", "Maya"])
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

    @Test func inAppFilterHidesRatingsAndKeepsMatches() {
        let now = Date()
        var filter = ChannelPrefs()
        filter.friendRatings = false
        filter.commentsLikes = false
        let feed = ActivityFeed.make(
            inbox: ActivityPreview.inbox(now: now),
            incoming: [],
            useInboxFriendRequests: false,
            filter: filter,
            now: now
        )
        let rows = feed.sections.flatMap(\.rows)

        #expect(rows.contains { $0.route == .movie(tmdbId: 531428, title: "Portrait of a Lady on Fire") })
        #expect(!rows.contains { $0.lineLead == "Ken" })
        #expect(!rows.contains { $0.lineLead == "Sam and 3 others" })
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
        #expect(ActivityFeed.deepLink(type: "follow_request", data: [:]) == .friendRequests)
    }

    @Test func legacyPreferencesLeaveLocalChannelsAlone() throws {
        var local = NotificationPrivacyPrefs()
        local.inApp.friendRatings = false
        local.push.watchedWith = false
        local.shareRatings = .off
        let server = NotificationPreferences(
            friendRequests: true,
            groupInvites: false,
            recommendations: true,
            friendActivity: false,
            commentReplies: true
        )

        let merged = local.applying(server: server)

        #expect(merged.push.friendRatings == false)
        #expect(merged.push.blendActivity == false)
        #expect(merged.push.commentsLikes == true)
        #expect(merged.push.recommendations == true)
        #expect(merged.push.watchedWith == false)
        #expect(merged.inApp.friendRatings == false)
        #expect(merged.shareRatings == .off)
    }

    @Test func decodesLegacyAndRichPreferences() throws {
        let legacy = """
        {"friend_requests":true,"group_invites":false,"recommendations":true,\
        "friend_activity":false,"comment_replies":true}
        """
        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: Data(legacy.utf8))
        #expect(decoded.groupInvites == false)
        #expect(decoded.shareRatings == nil)
        #expect(decoded.inApp == nil)

        let rich = """
        {"friend_requests":true,"group_invites":true,"recommendations":true,\
        "friend_activity":true,"comment_replies":true,"share_ratings":"everyone",\
        "in_app":{"friend_ratings":false,"blend_activity":true,"comments_likes":true,\
        "watched_with":true,"recommendations":false}}
        """
        let extra = try JSONDecoder().decode(NotificationPreferences.self, from: Data(rich.utf8))
        #expect(extra.shareRatings == "everyone")
        #expect(extra.inApp?.friendRatings == false)
        #expect(extra.inApp?.recommendations == false)
    }

    @Test func patchOmitsFriendRequestsAndCanDropExtensions() throws {
        let request = NotificationPrivacyPrefs(shareRatings: .off).asRequest()
        let full = try JSONSerialization.jsonObject(with: try encoded(request, extensions: true)) as? [String: Any]
        let legacy = try JSONSerialization.jsonObject(with: try encoded(request, extensions: false)) as? [String: Any]

        #expect(full?["friend_requests"] == nil)
        #expect(full?["share_ratings"] as? String == "off")
        #expect(full?["friend_activity"] as? Bool == true)
        #expect(full?["in_app"] != nil)
        #expect(legacy?["share_ratings"] == nil)
        #expect(legacy?["in_app"] == nil)
        #expect(legacy?["group_invites"] as? Bool == true)
    }

    private func encoded(_ request: UpdatePreferencesRequest, extensions: Bool) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(PreferencePatchBox(request: request, includeExtensions: extensions))
    }
}

private struct PreferencePatchBox: Encodable {
    let request: UpdatePreferencesRequest
    let includeExtensions: Bool

    func encode(to encoder: Encoder) throws {
        try request.encode(to: encoder, includeExtensions: includeExtensions)
    }
}
