@testable import blnd_ios
import Foundation
import Testing

struct TimelineTests {
    private func person(_ name: String, id: String? = nil) -> TimelinePerson {
        TimelinePerson(id: id ?? name.lowercased(), name: name, avatar: nil)
    }

    private func entry(
        logId: Int?,
        title: String,
        date: String?,
        createdAt: String? = nil,
        tmdb: Int,
        type: MediaType = .movie
    ) -> TimelineEntry {
        TimelineEntry(
            logId: logId,
            createdAt: createdAt,
            date: date,
            media: TimelineMedia(tmdbId: tmdb, title: title, poster: nil, year: nil, mediaType: type),
            user: person("You")
        )
    }

    @Test func diaryLineForTwoFriends() {
        let line = DiaryCopy.watchedWithLine([person("Alex"), person("Sam")])
        #expect(line == "with Alex & Sam")
    }

    @Test func diaryLineForOneAndThreeFriends() {
        #expect(DiaryCopy.watchedWithLine([person("Alex")]) == "with Alex")
        let line = DiaryCopy.watchedWithLine([person("Alex"), person("Sam"), person("Jordan")])
        #expect(line == "with Alex, Sam & Jordan")
    }

    @Test func diaryLineSkipsBlankNames() {
        let line = DiaryCopy.watchedWithLine([
            TimelinePerson(id: "a", name: "   ", avatar: nil),
            person("Sam"),
        ])
        #expect(line == "with Sam")
    }

    @Test func diaryLineIsNilWithoutPeople() {
        #expect(DiaryCopy.watchedWithLine([]) == nil)
    }

    @Test func pickerStopsAtFifty() {
        var selected = Set((1 ... 50).map(String.init))
        let blocked = DiaryCopy.toggle("51", in: selected)
        #expect(blocked.hitCap)
        #expect(blocked.selected.count == 50)

        let removed = DiaryCopy.toggle("1", in: selected)
        #expect(!removed.hitCap)
        #expect(removed.selected.count == 49)

        selected = []
        let cleared = DiaryCopy.toggle("1", in: selected)
        #expect(cleared.selected == ["1"])
        let empty = DiaryCopy.toggle("1", in: cleared.selected)
        #expect(empty.selected.isEmpty)
    }

    @Test func groupingOrdersMonthsAndLeavesUndatedLast() {
        let october = entry(logId: 1, title: "Late", date: "2026-10-12", tmdb: 1)
        let octoberEarlier = entry(logId: 2, title: "Early", date: "2026-10-02", tmdb: 2)
        let september = entry(logId: 3, title: "Sept", date: "2026-09-18", tmdb: 3)
        let undated = entry(logId: 4, title: "Unknown", date: "nope", tmdb: 4)

        let sections = TimelineGrouping.sections(from: [september, undated, octoberEarlier, october])

        #expect(sections.map(\.title) == ["October 2026", "September 2026", "No date"])
        #expect(sections[0].entries.map(\.media.title) == ["Late", "Early"])
        #expect(sections[2].entries.map(\.media.title) == ["Unknown"])
    }

    @Test func diaryDateWinsOverCreatedAt() {
        let row = entry(
            logId: 1,
            title: "Paper Cities",
            date: "2026-10-12",
            createdAt: "2026-01-01T00:00:00.000000Z",
            tmdb: 1
        )
        #expect(TimelineDate.dayParts(of: row) == TimelineDay(year: 2026, month: 10, day: 12))
    }

    @Test func fractionalCreatedAtParsesWhenDateIsMissing() {
        let stamp = "2026-10-15T08:14:59.352080Z"
        let instant = TimelineDate.parseTimestamp(stamp)
        #expect(instant != nil)
        let row = entry(logId: 9, title: "Late Show", date: nil, createdAt: stamp, tmdb: 9)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(TimelineDate.dayParts(of: row, calendar: utc) == TimelineDay(year: 2026, month: 10, day: 15))
    }

    @Test func decodeTimelinePageMatchesContract() throws {
        let json = """
        {
          "results": [
            {
              "id": 42,
              "created_at": "2026-10-15T08:14:59.352080Z",
              "date": "2026-10-12",
              "rating": 4.5,
              "media": {
                "tmdb_id": 8810,
                "title": "Paper Cities",
                "poster": "/paper.jpg",
                "year": 2024,
                "media_type": "tv"
              },
              "user": {"id": "u1", "name": "Maya", "avatar": null},
              "watched_with": [
                {"id": "a", "name": "Alex", "avatar": null},
                {"id": "s", "name": "Sam", "avatar": null}
              ]
            },
            {
              "date": "2026-09-01",
              "rating": null,
              "media": {
                "tmdb_id": 7,
                "title": "No Id Yet",
                "poster": null,
                "year": null,
                "media_type": "movie"
              },
              "user": {"id": "u2", "name": "Chris", "avatar": null}
            }
          ],
          "next_cursor": null
        }
        """
        let page = try JSONDecoder().decode(TimelinePage.self, from: Data(json.utf8))
        #expect(page.nextCursor == nil)
        #expect(page.results[0].logId == 42)
        #expect(page.results[0].createdAt == "2026-10-15T08:14:59.352080Z")
        #expect(page.results[0].media.isTV)
        #expect(page.results[0].media.poster == "/paper.jpg")
        #expect(page.results[0].user.name == "Maya")
        #expect(DiaryCopy.watchedWithLine(page.results[0].watchedWith) == "with Alex & Sam")
        #expect(page.results[1].logId == nil)
        #expect(page.results[1].createdAt == nil)
        #expect(page.results[1].watchedWith.isEmpty)
        #expect(!page.results[1].media.isTV)
    }

    @Test func decodeWatchedWithResponse() throws {
        let json = """
        {"watched_with":[{"id":"a","name":"Alex","avatar":null}]}
        """
        let response = try JSONDecoder().decode(WatchedWithResponse.self, from: Data(json.utf8))
        #expect(response.watchedWith.first?.id == "a")
        #expect(response.watchedWith.first?.name == "Alex")
    }

    @Test func cursorPageStopsWhenNextCursorIsNull() throws {
        let json = #"{"results":[],"next_cursor":"abc"}"#
        let page = try JSONDecoder().decode(TimelinePage.self, from: Data(json.utf8))
        #expect(page.nextCursor == "abc")
    }

    @Test func errorEnvelopeMessage() {
        let body = #"{"error":{"code":"NOT_FOUND","message":"Group not found"},"detail":"Group not found"}"#
        #expect(APIErrorEnvelope.message(from: Data(body.utf8)) == "Group not found")
        #expect(TimelineLoadFailure.from(APIError.notFound) == .unavailable)
        #expect(TimelineLoadFailure.from(APIError.badRequest(APIFieldError(
            code: nil,
            issues: [APIIssue(field: nil, text: "nope")],
            raw: "nope",
            opensPaywall: false
        ))) == .message("Something in that didn't look right."))
    }
}
