@testable import blnd_ios
import Foundation
import Testing

struct TimelineTests {
    private func person(_ name: String, displayName: String? = nil) -> WatchCompanion {
        WatchCompanion(
            userId: name.lowercased(),
            username: name.lowercased(),
            displayName: displayName ?? name,
            avatarUrl: nil
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

    @Test func diaryLineUsesUsernameWhenDisplayNameIsBlank() {
        let line = DiaryCopy.watchedWithLine([
            person("alex", displayName: "   "),
            person("Sam"),
        ])
        #expect(line == "with alex & Sam")
    }

    @Test func diaryLineIsNilWithoutPeople() {
        #expect(DiaryCopy.watchedWithLine([]) == nil)
    }

    @Test func groupingOrdersMonthsAndLeavesUndatedLast() {
        let october = TimelineEntry(id: 1, tmdbId: 1, title: "Late", watchedDate: "2026-10-12")
        let octoberEarlier = TimelineEntry(id: 2, tmdbId: 2, title: "Early", watchedDate: "2026-10-02")
        let september = TimelineEntry(id: 3, tmdbId: 3, title: "Sept", watchedDate: "2026-09-18")
        let undated = TimelineEntry(id: 4, tmdbId: 4, title: "Unknown", watchedDate: "nope")

        let sections = TimelineGrouping.sections(from: [september, undated, octoberEarlier, october])

        #expect(sections.map(\.title) == ["October 2026", "September 2026", "No date"])
        #expect(sections[0].entries.map(\.title) == ["Late", "Early"])
        #expect(sections[2].entries.map(\.title) == ["Unknown"])
    }

    @Test func watchedDateWinsOverCreatedAt() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let entry = TimelineEntry(
            id: 1,
            tmdbId: 1,
            title: "Paper Cities",
            watchedDate: "2026-10-12",
            createdAt: "2026-01-01T00:00:00Z"
        )
        let day = TimelineDate.dayParts(of: entry, calendar: calendar)
        #expect(day == TimelineDay(year: 2026, month: 10, day: 12))
    }

    @Test func decodeTimelinePageDefaultsMissingCompanions() throws {
        let json = """
        {
          "results": [
            {
              "id": 7,
              "tmdb_id": 550,
              "title": "Paper Cities",
              "rating": 4.5,
              "watched_date": "2026-10-12",
              "watched_with": [
                {"user_id": "a", "username": "alex", "display_name": "Alex"}
              ]
            }
          ],
          "total": 1
        }
        """
        let page = try JSONDecoder().decode(TimelinePage.self, from: Data(json.utf8))
        #expect(page.total == 1)
        #expect(page.results[0].watchedWith.first?.name == "Alex")
        #expect(page.results[0].watchedBy == nil)
        #expect(DiaryCopy.watchedWithLine(page.results[0].watchedWith) == "with Alex")
    }

    @Test func missingEndpointMapsToUnavailable() {
        #expect(TimelineLoadFailure.from(APIError.notFound) == .unavailable)
        #expect(TimelineLoadFailure.from(APIError.badRequest("nope")) == .message("nope"))
    }
}
