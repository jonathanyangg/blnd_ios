@testable import blnd_ios
import Testing

private final class RecordingSink: HapticSink {
    var played: [Haptic] = []
    func play(_ haptic: Haptic) { played.append(haptic) }
}

@MainActor
@Suite(.serialized)
struct QoLPolishTests {
    private func withRecordingSink(_ body: () -> Void) -> [Haptic] {
        let original = Haptics.sink
        let sink = RecordingSink()
        Haptics.sink = sink
        defer { Haptics.sink = original }
        body()
        return sink.played
    }

    @Test(arguments: [Haptic.tap, .select, .success, .warning, .error])
    func sinkReceivesEachHaptic(_ haptic: Haptic) {
        #expect(withRecordingSink { Haptics.play(haptic) } == [haptic])
    }

    @Test func sinkReceivesHapticsInOrder() {
        let played = withRecordingSink {
            Haptics.play(.select)
            Haptics.play(.success)
            Haptics.play(.warning)
        }
        #expect(played == [.select, .success, .warning])
    }

    @Test func refreshHapticReflectsOutcome() {
        #expect(Haptic.refreshed(ok: true) == .success)
        #expect(Haptic.refreshed(ok: false) == .error)
    }

    // MARK: - LoadState

    private let failure = UserFacingError.client(.server, message: "Couldn't load")

    @Test func loadingWhenEmptyAndLoading() {
        #expect(LoadState.resolve(isLoading: true, error: nil, isEmpty: true) == .loading)
        #expect(LoadState.resolve(isLoading: true, error: failure, isEmpty: true) == .loading)
    }

    @Test func errorWhenEmptyAndFailed() {
        #expect(LoadState.resolve(isLoading: false, error: failure, isEmpty: true) == .error(failure))
    }

    @Test func emptyWhenNothingLoadedAndNoError() {
        #expect(LoadState.resolve(isLoading: false, error: nil, isEmpty: true) == .empty)
    }

    @Test func contentWinsOverLoadingAndError() {
        // Keeps the grid on screen during pull-to-refresh or a failed reload.
        #expect(LoadState.resolve(isLoading: true, error: nil, isEmpty: false) == .content)
        #expect(LoadState.resolve(isLoading: false, error: failure, isEmpty: false) == .content)
        #expect(LoadState.resolve(isLoading: false, error: nil, isEmpty: false) == .content)
    }
}
