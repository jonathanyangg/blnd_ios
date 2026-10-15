@testable import blnd_ios
import Foundation
import Testing

struct LetterboxdExportTests {
    @Test func nestedZipFlattensAndCountsRatings() throws {
        let zip = ZipArchive.archive(
            [
                "letterboxd-demo/watched.csv": Data(watchedCSV.utf8),
                "letterboxd-demo/ratings.csv": Data(ratingsCSV.utf8),
                "letterboxd-demo/likes/films.csv": Data(likesCSV.utf8),
                "letterboxd-demo/diary.csv": Data("Date,Name\n".utf8),
            ],
            method: 8
        )

        let prepared = try LetterboxdExport.prepare(data: zip, filename: "letterboxd.zip")
        let files = try ZipArchive.extractLetterboxdFiles(prepared.zipData)

        #expect(prepared.ratingsCount == 2)
        #expect(files["watched.csv"] != nil)
        #expect(files["ratings.csv"] != nil)
        #expect(files["likes/films.csv"] != nil)
        #expect(files["diary.csv"] == nil)
        #expect(String(decoding: files["ratings.csv"] ?? Data(), as: UTF8.self).contains("The Good, the Bad and the Ugly"))
    }

    @Test func ratingsFileAlsoBecomesWatched() throws {
        let prepared = try LetterboxdExport.prepare(data: Data(ratingsCSV.utf8), filename: "ratings.csv")
        let files = try ZipArchive.extractLetterboxdFiles(prepared.zipData)

        #expect(prepared.ratingsCount == 2)
        #expect(files["watched.csv"] != nil)
        #expect(String(decoding: files["watched.csv"] ?? Data(), as: UTF8.self).contains("letterboxd.com/film/heat"))
    }

    @Test func watchedRatingsAreCopiedIntoRatingsFile() throws {
        let watchedWithRating = """
        Date,Name,Year,Letterboxd URI,Rating
        2020-01-03,Heat,1995,https://letterboxd.com/film/heat/,4.5
        """
        let prepared = try LetterboxdExport.prepare(
            data: Data(watchedWithRating.utf8),
            filename: "watched.csv"
        )
        let files = try ZipArchive.extractLetterboxdFiles(prepared.zipData)

        #expect(prepared.ratingsCount == 1)
        #expect(String(decoding: files["ratings.csv"] ?? Data(), as: UTF8.self).contains("4.5"))
    }

    @Test func wrongFileIsRejected() {
        #expect(throws: LetterboxdExportError.wrongFile) {
            try LetterboxdExport.prepare(data: Data("hello".utf8), filename: "notes.txt")
        }
        #expect(throws: LetterboxdExportError.wrongFile) {
            try LetterboxdExport.prepare(data: Data("a,b\n1,2\n".utf8), filename: "watched.csv")
        }
        let diaryZip = ZipArchive.store(["diary.csv": Data("Date,Name\n".utf8)])
        #expect(throws: LetterboxdExportError.wrongFile) {
            try LetterboxdExport.prepare(data: diaryZip, filename: "export.zip")
        }
    }

    @Test func brokenZipIsUnreadable() {
        #expect(throws: LetterboxdExportError.unreadable) {
            try LetterboxdExport.prepare(data: Data([0x50, 0x4B, 0x03, 0x04, 0x00]), filename: "export.zip")
        }
    }

    @Test func oversizedFileIsRejected() {
        let huge = Data(count: LetterboxdExport.maxUploadBytes + 1)
        #expect(throws: LetterboxdExportError.tooLarge) {
            try LetterboxdExport.prepare(data: huge, filename: "export.zip")
        }
    }

    private let watchedCSV = """
    Date,Name,Year,Letterboxd URI
    2020-01-02,"The Good, the Bad and the Ugly",1966,https://letterboxd.com/film/the-good-the-bad-and-the-ugly/
    2020-01-03,Heat,1995,https://letterboxd.com/film/heat/
    """

    private let ratingsCSV = """
    Date,Name,Year,Letterboxd URI,Rating
    2020-01-02,"The Good, the Bad and the Ugly",1966,https://letterboxd.com/film/the-good-the-bad-and-the-ugly/,5
    2020-01-03,Heat,1995,https://letterboxd.com/film/heat/,4.5
    """

    private let likesCSV = """
    Date,Name,Year,Letterboxd URI
    2020-01-03,Heat,1995,https://letterboxd.com/film/heat/
    """
}
