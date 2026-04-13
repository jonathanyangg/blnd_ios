import Foundation

enum APIConfig {
    /// static let baseURL = "https://blnd-backend.onrender.com"
    static let baseURL = "http://localhost:8000" // TODO: switch back to prod before deploy

    /// Set to true before taking App Store screenshots.
    /// Blurs movie posters to avoid copyright issues.
    static let screenshotMode = false
}
