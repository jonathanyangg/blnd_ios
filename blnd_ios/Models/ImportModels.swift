import Foundation

/// Response model for a completed Letterboxd import.
/// Mirrors `blnd_backend/app/import_data/schemas.py` `ImportSummaryResponse`.
struct ImportSummaryResponse: Decodable {
    let imported: Int
    let skipped: Int
    let failed: Int
    let failedTitles: [String]

    enum CodingKeys: String, CodingKey {
        case imported
        case skipped
        case failed
        case failedTitles = "failed_titles"
    }
}
