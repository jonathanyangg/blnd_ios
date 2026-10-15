import Foundation

enum APIConfig {
//    static let baseURL = "https://blnd-backend.onrender.com"
    // swiftformat:disable docComments
    static var baseURL: String {
        let args = ProcessInfo.processInfo.arguments
        if let flag = args.firstIndex(of: "-apiBaseURL"),
           args.indices.contains(args.index(after: flag)) {
            return args[args.index(after: flag)]
        }
        return "http://192.168.7.121:8000" // local dev
    }
    // swiftformat:enable docComments

    /// Set to true before taking App Store screenshots.
    /// Blurs movie posters to avoid copyright issues.
    static let screenshotMode = false
}
