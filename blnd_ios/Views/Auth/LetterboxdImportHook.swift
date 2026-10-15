import SwiftUI

/// Onboarding's only link into Letterboxd import.
/// PR #14 (`ImportContextView` question state) and the redesign on that
/// branch own the screen. Replace `screen()` when that UI lands.
enum LetterboxdImportHook {
    static func screen() -> some View {
        ImportContextView()
    }
}
