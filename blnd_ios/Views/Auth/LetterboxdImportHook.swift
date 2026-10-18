import SwiftUI

/// Onboarding's entry into the "Bring your movies" hub.
enum BringMoviesEntry {
    static func screen(onFinished: @escaping () -> Void) -> some View {
        MovieImportFlow(onComplete: onFinished, onSkip: onFinished)
    }
}
