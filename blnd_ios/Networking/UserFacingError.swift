import Foundation

/// Categories the user can actually act on. Raw server text never lands in one of these.
enum ErrorCategory: String, Equatable, Sendable {
    case offline
    case timeout
    case authExpired = "auth_expired"
    case notFound = "not_found"
    case server
    case validation
}

/// Friendly copy for an error. Build it with `map` or `capture`. Views render this, never `localizedDescription`.
struct UserFacingError: Equatable, Sendable {
    let category: ErrorCategory
    let title: String
    let message: String

    var icon: String {
        switch category {
        case .offline: "wifi.slash"
        case .timeout: "clock"
        case .authExpired: "person.crop.circle.badge.exclamationmark"
        case .notFound: "magnifyingglass"
        case .server: "exclamationmark.triangle"
        case .validation: "exclamationmark.circle"
        }
    }

    /// Client-authored copy. Do not pass a server body or `localizedDescription` here.
    static func client(
        _ category: ErrorCategory,
        title: String? = nil,
        message: String
    ) -> UserFacingError {
        let base = copy(for: category)
        return UserFacingError(
            category: category,
            title: title ?? base.title,
            message: message
        )
    }

    /// Maps any error onto friendly copy. Does not log.
    static func map(_ error: Error) -> UserFacingError {
        if let api = error as? APIError {
            return mapAPI(api)
        }
        if let url = error as? URLError {
            return mapURL(url)
        }
        return copy(for: .server)
    }

    /// Maps the error, prints the raw detail, and sends that detail to PostHog.
    static func capture(_ error: Error, screen: String) -> UserFacingError {
        let copy = map(error)
        let detail = diagnostic(error)
        print("[blnd error] \(screen) \(copy.category.rawValue): \(detail)")
        Analytics.errorShown(
            screen: screen,
            category: copy.category.rawValue,
            detail: detail
        )
        return copy
    }

    private static func mapAPI(_ error: APIError) -> UserFacingError {
        switch error {
        case let .networkError(inner):
            return map(inner)
        case .unauthorized:
            return copy(for: .authExpired)
        case .notFound:
            return copy(for: .notFound)
        case .badRequest:
            return copy(for: .validation)
        case .rateLimited:
            return UserFacingError(
                category: .server,
                title: "Slow down",
                message: "Too many requests. Try again in a minute."
            )
        case .invalidURL, .refreshUnavailable, .serverError, .decodingError:
            return copy(for: .server)
        }
    }

    private static func mapURL(_ error: URLError) -> UserFacingError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .internationalRoamingOff, .cannotConnectToHost, .cannotFindHost,
             .dnsLookupFailed:
            return copy(for: .offline)
        case .timedOut:
            return copy(for: .timeout)
        default:
            return copy(for: .server)
        }
    }

    private static func copy(for category: ErrorCategory) -> UserFacingError {
        let text: (title: String, message: String) = switch category {
        case .offline:
            ("You're offline", "Check your connection and try again.")
        case .timeout:
            ("Request timed out", "That took too long. Try again.")
        case .authExpired:
            ("Sign in again", "We couldn't verify your account. Check your details and try again.")
        case .notFound:
            ("Not found", "We couldn't find that.")
        case .server:
            ("Something went wrong", "Please try again in a moment.")
        case .validation:
            ("Check that again", "Something in that didn't look right.")
        }
        return UserFacingError(category: category, title: text.title, message: text.message)
    }

    /// Full error for the console and PostHog. Not safe to show in the UI.
    static func diagnostic(_ error: Error) -> String {
        let raw: String = switch error {
        case let api as APIError:
            switch api {
            case .invalidURL: "invalidURL"
            case .unauthorized: "unauthorized"
            case .refreshUnavailable: "refreshUnavailable"
            case let .badRequest(message): "badRequest: \(message)"
            case .notFound: "notFound"
            case let .rateLimited(detail): "rateLimited: \(detail ?? "")"
            case let .serverError(code): "serverError: \(code)"
            case .decodingError: "decodingError"
            case let .networkError(inner): "networkError: \(diagnostic(inner))"
            }
        case let url as URLError:
            "URLError \(url.code.rawValue): \(url.localizedDescription)"
        default:
            "\(type(of: error)): \(error.localizedDescription)"
        }
        if raw.count <= 500 { return raw }
        return String(raw.prefix(500))
    }
}
