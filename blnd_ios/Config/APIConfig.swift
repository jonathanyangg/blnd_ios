import Foundation

enum APIConfig {
    /// Production URL. Debug sets `BLND_API_BASE_URL` in the shared scheme
    /// (localhost on the simulator). Do not hardcode a LAN address here.
    static let baseURL: String = {
        let override = ProcessInfo.processInfo.environment["BLND_API_BASE_URL"]
        if let override, !override.isEmpty {
            return override
        }
        return "https://blnd-backend.onrender.com"
    }()

    /// Set to true before taking App Store screenshots.
    /// Blurs movie posters to avoid copyright issues.
    static let screenshotMode = false
}
