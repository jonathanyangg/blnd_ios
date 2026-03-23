import CryptoKit
import Foundation
import Security

/// Utilities for Apple Sign In nonce generation and hashing.
enum AppleSignInHelper {
    /// Generates a cryptographically secure random nonce string.
    ///
    /// Uses `SecRandomCopyBytes` for secure randomness, mapping bytes
    /// to a URL-safe character set.
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(
                kSecRandomDefault, randoms.count, &randoms
            )
            precondition(status == errSecSuccess, "Failed to generate random bytes")

            for random in randoms {
                guard remainingLength > 0 else { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    /// Returns the SHA-256 hash of the input string as a lowercase hex string.
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
