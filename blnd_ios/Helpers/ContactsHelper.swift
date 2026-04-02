import Contacts
import Foundation

enum ContactsHelper {
    /// Request contacts access and return all phone numbers in E.164 format.
    static func fetchPhoneNumbers() async -> [String] {
        let store = CNContactStore()

        // Request access
        let authorized: Bool
        do {
            authorized = try await store.requestAccess(for: .contacts)
        } catch {
            return []
        }
        guard authorized else { return [] }

        // Fetch all contacts with phone numbers
        let keys: [CNKeyDescriptor] = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var numbers: Set<String> = []
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                for phone in contact.phoneNumbers {
                    let raw = phone.value.stringValue
                    if let normalized = normalizePhoneNumber(raw) {
                        numbers.insert(normalized)
                    }
                }
            }
        } catch {
            return []
        }

        return Array(numbers)
    }

    /// Normalize a phone number to E.164 format.
    /// Strips non-digit chars (except leading +), defaults to +1 (US) if no country code.
    private static func normalizePhoneNumber(_ raw: String) -> String? {
        let stripped = raw.replacingOccurrences(
            of: "[^0-9+]",
            with: "",
            options: .regularExpression
        )
        guard !stripped.isEmpty else { return nil }

        // Already has country code
        if stripped.hasPrefix("+") {
            return stripped.count >= 8 ? stripped : nil
        }

        // US number starting with 1
        if stripped.hasPrefix("1"), stripped.count == 11 {
            return "+\(stripped)"
        }

        // Assume US if 10 digits
        if stripped.count == 10 {
            return "+1\(stripped)"
        }

        return nil
    }
}
