@testable import blnd_ios
import Foundation
import Testing

@MainActor
struct RecentSearchesTests {
    private func makeDefaults() -> UserDefaults {
        let name = "RecentSearchesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func newestFirstAndCappedAtTen() {
        let store = RecentSearchesStore(defaults: makeDefaults())
        for index in 1 ... 12 {
            store.record("query \(index)")
        }
        #expect(store.items.count == 10)
        #expect(store.items.first == "query 12")
        #expect(store.items.last == "query 3")
    }

    @Test func caseInsensitiveDuplicateMovesToTop() {
        let store = RecentSearchesStore(defaults: makeDefaults())
        store.record("Inception")
        store.record("Dune")
        store.record("inception")
        #expect(store.items == ["inception", "Dune"])
    }

    @Test func trimsWhitespace() {
        let store = RecentSearchesStore(defaults: makeDefaults())
        store.record("  Dune \n")
        #expect(store.items == ["Dune"])
    }

    @Test func ignoresQueriesShorterThanTwoCharacters() {
        let store = RecentSearchesStore(defaults: makeDefaults())
        store.record("")
        store.record("a")
        store.record("   b  ")
        #expect(store.items.isEmpty)
        store.record("ab")
        #expect(store.items == ["ab"])
    }

    @Test func removesOneItem() {
        let store = RecentSearchesStore(defaults: makeDefaults())
        store.record("Alien")
        store.record("Heat")
        store.record("Dune")
        store.remove("Heat")
        #expect(store.items == ["Dune", "Alien"])
    }

    @Test func clearAllEmptiesStoreAndStorage() {
        let defaults = makeDefaults()
        let store = RecentSearchesStore(defaults: defaults)
        store.record("Alien")
        store.record("Heat")
        store.clearAll()
        #expect(store.items.isEmpty)
        #expect(RecentSearchesStore(defaults: defaults).items.isEmpty)
    }

    @Test func persistsAcrossInstancesInSameSuite() {
        let defaults = makeDefaults()
        let first = RecentSearchesStore(defaults: defaults)
        first.record("Alien")
        first.record("Heat")
        first.remove("Alien")
        first.record("Dune")
        #expect(RecentSearchesStore(defaults: defaults).items == ["Dune", "Heat"])
    }

    /// Pure on-device store: the only state it touches is its UserDefaults
    /// suite, stored as a plain JSON array of strings (no network, no ids).
    @Test func storesOnlyAJSONStringArrayInDefaults() throws {
        let defaults = makeDefaults()
        let store = RecentSearchesStore(defaults: defaults)
        store.record("Heat")
        let data = try #require(defaults.data(forKey: RecentSearchesStore.storageKey))
        let decoded = try JSONDecoder().decode([String].self, from: data)
        #expect(decoded == ["Heat"])
    }
}
