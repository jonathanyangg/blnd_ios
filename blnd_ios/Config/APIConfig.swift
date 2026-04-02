import Foundation

enum APIConfig {
    static let baseURL: String = {
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        return "https://blnd-backend.onrender.com"
        #endif
    }()

    /// Set to true before taking App Store screenshots.
    /// Blurs movie posters to avoid copyright issues.
    static let screenshotMode = false
}
