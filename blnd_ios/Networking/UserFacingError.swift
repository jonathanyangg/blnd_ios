import AuthenticationServices
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
    /// Friendly sentences for fields the user can fix. Empty when the message is generic.
    var fields: [String: String] = [:]
    var field: String?
    /// PREMIUM_REQUIRED, PAYMENT_REQUIRED, FREE_GROUP_CAP, or a legacy upgrade sentence.
    var opensPaywall: Bool = false

    /// The sentence for one field, when this error names it.
    func inline(for name: String) -> UserFacingError? {
        guard let text = fields[name] else { return nil }
        return UserFacingError(
            category: .validation,
            title: "Check that again",
            message: text,
            fields: [:],
            field: name
        )
    }

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

    /// Copy a screen may show. Sign in with Apple cancel is `nil` (show nothing).
    /// Every other error uses the envelope sentence or a friendly fallback, never `localizedDescription`.
    static func displayCopy(for error: Error) -> UserFacingError? {
        if appleAuthorizationCode(error) == ASAuthorizationError.canceled.rawValue {
            return nil
        }
        return map(error)
    }

    /// Maps any error onto friendly copy. Does not log.
    static func map(_ error: Error) -> UserFacingError {
        if let code = appleAuthorizationCode(error), code != ASAuthorizationError.canceled.rawValue {
            return client(.server, title: "Couldn't sign in", message: appleSignInMessage)
        }
        if let api = error as? APIError {
            return mapAPI(api)
        }
        if let url = error as? URLError {
            return mapURL(url)
        }
        return copy(for: .server)
    }

    private static let appleSignInMessage = "Couldn't sign in with Apple. Try again or use email."

    /// Code for an Apple authorization failure, including an `NSError` in that domain.
    private static func appleAuthorizationCode(_ error: Error) -> Int? {
        if let apple = error as? ASAuthorizationError {
            return apple.code.rawValue
        }
        let ns = error as NSError
        guard ns.domain == ASAuthorizationError.errorDomain else { return nil }
        return ns.code
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
        case let .badRequest(info):
            return mapFields(info)
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

    private static let paywallCodes: Set<String> = [
        "PREMIUM_REQUIRED", "PAYMENT_REQUIRED", "FREE_GROUP_CAP",
    ]

    /// Known sentences from the auth schema and the error-code list. Unknown text stays generic.
    private static let knownCopy: [String: (field: String?, message: String)] = [
        "username is already taken": ("username", "That username is taken."),
        "username must be 3-30 characters": ("username", "Usernames are 3–30 characters."),
        "username can only contain letters, numbers, periods, and underscores": (
            "username", "Use letters, numbers, periods, or underscores."
        ),
        "username cannot start or end with a period or underscore": (
            "username", "Don't start or end with a period or underscore."
        ),
        "username cannot contain consecutive periods or underscores": (
            "username", "Don't repeat periods or underscores."
        ),
        "password must be at least 8 characters": ("password", "Use at least 8 characters."),
        "password must contain at least one uppercase letter": ("password", "Add an uppercase letter."),
        "current password is incorrect": ("current_password", "That password doesn't match."),
        "cannot change password for this account": (
            "current_password", "This account doesn't use a password."
        ),
        "phone number must be in e.164 format (e.g. +15551234567)": (
            "phone_number", "Use a number like +15551234567."
        ),
        "phone number is already linked to another account": (
            "phone_number", "That number is already in use."
        ),
        "avatar url must use https": ("avatar_url", "The photo link must use https."),
        "avatar url too long": ("avatar_url", "That photo link is too long."),
        "genre name too long": ("favorite_genres", "One of those genre names is too long."),
        "value is not a valid email address": ("email", "That email doesn't look right."),
        "field required": (nil, "Fill this in."),
        "string should have at least 1 character": (nil, "Fill this in."),
        "string should have at most 30 characters": (nil, "That's too long."),
        "string should have at most 100 characters": (nil, "That's too long."),
        "string should have at most 250 characters": (nil, "That's too long."),
        "user is already a member": (nil, "They're already in this blend."),
        "this blend is full.": (nil, "This blend is full."),
    ]

    private static func mapFields(_ info: APIFieldError) -> UserFacingError {
        if info.opensPaywall || paywallCodes.contains(info.code ?? "") {
            return UserFacingError(
                category: .validation,
                title: "blnd+",
                message: "Upgrade to blnd+ to do this.",
                opensPaywall: true
            )
        }
        if info.code == "GROUP_FULL" {
            return UserFacingError(
                category: .validation,
                title: "Check that again",
                message: "This blend is full."
            )
        }
        var fields: [String: String] = [:]
        var loose: String?
        for issue in info.issues {
            let key = normalize(issue.text)
            guard let known = knownCopy[key] else { continue }
            let field = issue.field ?? known.field
            if let field {
                fields[field] = known.message
            } else if loose == nil {
                loose = known.message
            }
        }
        if let first = fields.first {
            return UserFacingError(
                category: .validation,
                title: "Check that again",
                message: first.value,
                fields: fields,
                field: first.key
            )
        }
        if let loose {
            return UserFacingError(
                category: .validation,
                title: "Check that again",
                message: loose
            )
        }
        return copy(for: .validation)
    }

    private static func normalize(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "Value error, "
        if value.lowercased().hasPrefix(prefix.lowercased()) {
            value = String(value.dropFirst(prefix.count))
        }
        return value.lowercased()
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
            case let .badRequest(info): "badRequest: \(info.code ?? "") \(info.raw)"
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
