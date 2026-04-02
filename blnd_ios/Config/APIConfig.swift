import Foundation

enum APIConfig {
    /// For local dev: "http://localhost:8000"
    static let baseURL = "https://blnd-backend.onrender.com"

    /// Set to true before taking App Store screenshots.
    /// Blurs movie posters to avoid copyright issues.
    static let screenshotMode = false
}
