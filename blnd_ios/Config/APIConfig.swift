import Foundation

enum APIConfig {
    static let baseURL = "https://blnd-backend.onrender.com"
    // static let baseURL = "http://192.168.1.44:8000" // local dev

    /// Set to true before taking App Store screenshots.
    /// Blurs movie posters to avoid copyright issues.
    static let screenshotMode = false
}
