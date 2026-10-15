import Foundation

enum APIConfig {
    /// `API_BASE_URL` is a per-configuration build setting copied into Info.plist.
    /// Debug uses the LAN server. Release uses https://blnd-backend.onrender.com.
    static let baseURL = resolvedBaseURL(Bundle.main.infoDictionary)

    static func resolvedBaseURL(_ info: [String: Any]?) -> String {
        let raw = (info?["API_BASE_URL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else {
            fatalError("API_BASE_URL missing or invalid in Info.plist")
        }
        return raw
    }

    /// Set to true before taking App Store screenshots.
    /// Blurs movie posters to avoid copyright issues.
    static let screenshotMode = false
}
