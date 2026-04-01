import Foundation

enum APIConfig {
    static let baseURL: String = {
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        return "http://192.168.1.166:8000"
        #endif
    }()

    /// Set to true before taking App Store screenshots.
    /// Blurs movie posters to avoid copyright issues.
    static let screenshotMode = false
}
