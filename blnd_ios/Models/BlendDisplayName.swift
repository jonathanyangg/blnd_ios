import Foundation

/// Snapchat-style title for a Blend that has no name of its own.
enum BlendDisplayName {
    static func title(storedName: String, memberNames: [String]) -> String {
        let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }

        let names = memberNames.map(firstName).filter { !$0.isEmpty }
        switch names.count {
        case 0:
            return "Blend"
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) & \(names[1])"
        case 3:
            return "\(names[0]), \(names[1]) & \(names[2])"
        default:
            return "\(names[0]), \(names[1]) +\(names.count - 2)"
        }
    }

    static func firstName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.split(whereSeparator: \.isWhitespace).first else {
            return ""
        }
        return String(first)
    }
}
