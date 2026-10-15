import Foundation

/// Text the Share Extension hands to the app through the app group.
/// Compiled into both targets so the suite name cannot drift.
enum NotesShareText {
    static let suiteName = "group.com.jonathan.blnd-ios"
    static let inboxKey = "pendingNotesImport"
    static let openURL = URL(string: "blnd://import-notes")!

    /// Joins share-sheet parts. Blank parts are dropped.
    static func joined(_ parts: [String]) -> String? {
        let text = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return text.isEmpty ? nil : text
    }

    static func save(_ text: String) {
        guard let text = joined([text]) else { return }
        UserDefaults(suiteName: suiteName)?.set(text, forKey: inboxKey)
    }

    /// Reads the pending note and removes it so it is imported once.
    static func consume() -> String? {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        let text = defaults.string(forKey: inboxKey)
        defaults.removeObject(forKey: inboxKey)
        return joined(text.map { [$0] } ?? [])
    }

    static func isOpenURL(_ url: URL) -> Bool {
        url.scheme == "blnd" && url.host == "import-notes"
    }
}
