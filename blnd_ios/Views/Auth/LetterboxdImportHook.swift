import SwiftUI

/// Onboarding's only link into Letterboxd import.
/// PR #14 owns `ImportContextView`. The import redesign opens it from the hub.
enum LetterboxdImportHook {
    static func screen() -> some View {
        ImportContextView()
    }
}

/// Onboarding's entry into the "Bring your movies" hub.
/// The other agent's `MovieImportFlow` / `BringMoviesHub` is not on this branch.
/// When it merges, replace `screen()` with:
/// `MovieImportFlow(onComplete: onFinished, onSkip: onFinished)`.
enum BringMoviesEntry {
    static func screen(onFinished: @escaping () -> Void) -> some View {
        BringMoviesStandIn(onFinished: onFinished)
    }
}

/// Stand-in hub: Letterboxd works today. Photos and notes stay on the real hub.
private struct BringMoviesStandIn: View {
    var onFinished: () -> Void
    @State private var showLetterboxd = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Bring your movies")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 24)
                Text("Start from Letterboxd. Photos and notes land here when the import hub merges.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
                Button {
                    showLetterboxd = true
                } label: {
                    HStack {
                        Text("Letterboxd")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                }
                .accessibilityIdentifier("import.hub.letterboxd")
                Spacer()
                AppButton(label: "Skip for now", style: .ghost, action: onFinished)
                    .accessibilityIdentifier("import.skip")
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background)
            .navigationDestination(isPresented: $showLetterboxd) {
                LetterboxdImportHook.screen()
            }
        }
        .accessibilityIdentifier("import.hub")
    }
}
