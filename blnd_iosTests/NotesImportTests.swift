@testable import blnd_ios
import Foundation
import Testing
import UIKit

@MainActor
struct NotesImportTests {
    @Test func decodesMatchContract() throws {
        let json = """
        {
          "items": [
            {
              "query": "Heat",
              "confidence": "high",
              "candidates": [
                {"tmdb_id": 949, "title": "Heat", "year": 1995, "poster_path": "/heat.jpg"}
              ]
            },
            {
              "query": "Godfather",
              "confidence": "low",
              "candidates": [
                {"tmdb_id": 238, "title": "The Godfather", "year": 1972, "poster_path": null},
                {"tmdb_id": 240, "title": "The Godfather Part II", "year": 1974, "poster_path": null},
                {"tmdb_id": 242, "title": "The Godfather Part III", "year": 1990, "poster_path": null},
                {"tmdb_id": 241, "title": "Extra", "year": 2000, "poster_path": null}
              ]
            },
            {
              "query": "not a movie",
              "confidence": "none",
              "candidates": [
                {"tmdb_id": 1, "title": "Ignored", "year": null, "poster_path": null}
              ]
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(NotesImportResponse.self, from: Data(json.utf8))
        let items = NotesImportReview.items(from: response)

        #expect(items.count == 3)
        #expect(items[0].confidence == .high)
        #expect(items[0].isIncluded)
        #expect(items[0].picked?.tmdbId == 949)
        #expect(items[1].confidence == .low)
        #expect(!items[1].isIncluded)
        #expect(items[1].candidates.map(\.tmdbId) == [238, 240, 242])
        #expect(items[2].confidence == .none)
        #expect(items[2].candidates.isEmpty)
        #expect(NotesImportReview.selectedIds(from: items) == [949])
    }

    @Test func highWithoutCandidateIsAMiss() {
        let items = NotesImportReview.items(from: NotesImportResponse(items: [
            NotesImportLine(query: "Heat", confidence: .high, candidates: []),
        ]))

        #expect(items.first?.confidence == NotesMatchConfidence.none)
        #expect(items.first?.isIncluded == false)
    }

    @Test func selectedIdsSkipUncheckedAndDuplicates() {
        var items = NotesImportReview.items(from: NotesImportResponse(items: [
            NotesImportLine(
                query: "Heat",
                confidence: .high,
                candidates: [NotesImportCandidate(tmdbId: 949, title: "Heat", year: 1995, posterPath: nil)]
            ),
            NotesImportLine(
                query: "Heat again",
                confidence: .low,
                candidates: [NotesImportCandidate(tmdbId: 949, title: "Heat", year: 1995, posterPath: nil)]
            ),
        ]))
        items[1].picked = items[1].candidates[0]
        items[1].isIncluded = true
        items[0].isIncluded = false

        #expect(NotesImportReview.selectedIds(from: items) == [949])
    }

    @Test func foundTitlePluralizes() {
        #expect(NotesImportReview.foundTitle(count: 1) == "We found 1 movie")
        #expect(NotesImportReview.foundTitle(count: 3) == "We found 3 movies")
    }

    @Test func rejectsEmptyAndHugeNotes() {
        #expect(throws: NotesImportError.empty) {
            try NotesImportReview.normalizedText("  \n")
        }
        #expect(throws: NotesImportError.tooLong) {
            try NotesImportReview.normalizedText(String(repeating: "a", count: 50001))
        }
    }

    @Test func commitResponseAllowsMissingRecommendations() throws {
        let json = #"{"saved":2}"#
        let response = try JSONDecoder().decode(NotesImportCommitResponse.self, from: Data(json.utf8))

        #expect(response.saved == 2)
        #expect(response.recommendations.isEmpty)
    }

    @Test func commitBodyUsesSnakeCaseIds() throws {
        let body = NotesImportCommitBody(bucket: "watchlist", tmdbIds: [238])
        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["bucket"] as? String == "watchlist")
        #expect(json?["tmdb_ids"] as? [Int] == [238])
    }
}

struct NotesRecognizerTests {
    @Test func recognizerReadsDrawnText() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 160)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 160))
            let line = "Heat" as NSString
            line.draw(
                at: CGPoint(x: 24, y: 48),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 64, weight: .bold),
                    .foregroundColor: UIColor.black,
                ]
            )
        }

        let text = try NotesTextRecognizer.text(in: [image])

        #expect(text.localizedCaseInsensitiveContains("heat"))
    }
}
