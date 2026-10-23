import UIKit

enum Haptic: Equatable, Sendable {
    case tap, select, success, warning, error

    static func refreshed(ok: Bool) -> Haptic { ok ? .success : .error }
}

protocol HapticSink {
    func play(_ haptic: Haptic)
}

struct UIKitHapticSink: HapticSink {
    func play(_ haptic: Haptic) {
        switch haptic {
        case .tap: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .select: UISelectionFeedbackGenerator().selectionChanged()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

enum Haptics {
    /// Swapped for a recording sink in tests.
    static var sink: HapticSink = UIKitHapticSink()

    static func play(_ haptic: Haptic) { sink.play(haptic) }
}
