import Foundation

/// On-device recent search queries (newest first), stored in UserDefaults.
@MainActor
@Observable
final class RecentSearchesStore {
    nonisolated static let storageKey = "blnd.recentSearches"
    static let limit = 10
    static let minLength = 2

    private(set) var items: [String]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        items = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    }

    func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minLength else { return }
        items.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        items.insert(trimmed, at: 0)
        items = Array(items.prefix(Self.limit))
        save()
    }

    func remove(_ query: String) {
        items.removeAll { $0 == query }
        save()
    }

    func clearAll() {
        items = []
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(items), forKey: Self.storageKey)
    }
}
