import SwiftUI

/// Asks "Did you watch <title>?" when the app comes back after a provider was
/// opened. The when-to-ask rules live in `PostWatchPrompt`.
struct PostWatchPromptHost: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var pending: PendingWatch?
    @State private var isChecking = false
    private let prompt = PostWatchPrompt()

    func body(content: Content) -> some View {
        content
            .task {
                #if DEBUG
                PostWatchPrompt.seedDemoIfRequested()
                #endif
                await check()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await check() }
            }
            // Swipe-down counts as "Not yet". After Yes/No the store is empty, so this is a no-op.
            .sheet(item: $pending, onDismiss: { prompt.snooze() }) { watch in
                PostWatchPromptSheet(watch: watch, prompt: prompt)
            }
    }

    private func check() async {
        guard pending == nil, !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        pending = await prompt.next { id in
            if UserActionCache.shared.isWatched(id) { return true }
            return (try? await TrackingAPI.getWatchedMovie(tmdbId: id)) != nil
        }
    }
}

private struct PostWatchPromptSheet: View {
    let watch: PendingWatch
    let prompt: PostWatchPrompt

    @Environment(\.dismiss) private var dismiss
    @State private var isRating = false

    var body: some View {
        if isRating {
            RateMovieSheet(title: watch.title, year: "", tmdbId: watch.tmdbId, posterPath: watch.posterPath)
                .presentationDetents([.medium, .large])
                .presentationBackground(AppTheme.card)
        } else {
            question
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.card)
        }
    }

    private var question: some View {
        VStack(spacing: 10) {
            Text("Did you watch \(watch.title)?")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Log it while it's fresh.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.bottom, 10)
            AppButton(label: "Yes — rate it") {
                prompt.resolve()
                isRating = true
            }
            .accessibilityIdentifier("postWatch.yes")
            HStack(spacing: 10) {
                secondary("Not yet", id: "postWatch.notYet") { prompt.snooze() }
                secondary("No", id: "postWatch.no") { prompt.resolve() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("postWatch.prompt")
    }

    private func secondary(_ label: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppTheme.cardSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
        .accessibilityIdentifier(id)
    }
}
