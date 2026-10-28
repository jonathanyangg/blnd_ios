@testable import blnd_ios
import Foundation
import Security
import Testing

struct KeychainAccessibilityTests {
    @Test func saveReplacesExistingItemWithDeviceOnlyAccess() {
        let key = "ponytail-keychain-\(UUID().uuidString)"
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(match as CFDictionary)
        defer { SecItemDelete(match as CFDictionary) }

        var seed = match
        seed[kSecValueData as String] = Data("old".utf8)
        seed[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        #expect(SecItemAdd(seed as CFDictionary, nil) == errSecSuccess)

        KeychainManager.save(key: key, string: "new")

        var read = match
        read[kSecReturnData as String] = true
        read[kSecReturnAttributes as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        #expect(SecItemCopyMatching(read as CFDictionary, &result) == errSecSuccess)

        let item = result as? [String: Any]
        #expect(item?[kSecValueData as String] as? Data == Data("new".utf8))
        let access = item?[kSecAttrAccessible as String] as? String
        #expect(access == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }
}
