# TV show support (iOS v1)

## Scope

This PR prepares the iOS client for the default-off backend TV API without
changing the movie flow. It adds decoding for TV responses, preserves missing
`media_type` as `nil`, exposes a deterministic TV badge decision, and routes a
new TV search call to `/tv/search`. No movie search UI is switched over yet.

## Acceptance criteria

| Criterion | Evidence | Status |
|---|---|---|
| TV search response decodes `tmdb_id`, `title`, `year`, and `media_type` | `decodeTVSearchResponse` | PROVEN |
| Existing movie responses remain decodable without `media_type` | `decodeMovieResponseWithoutMediaType` | PROVEN |
| TV badge decision follows decoded `media_type` | `tvBadgeDecisionUsesMediaType` | PROVEN at the pure-logic layer |
| Backend TV search integration with real API | Not testable until backend flag is enabled | NOT_PROVEN |
| Visible TV badge in SwiftUI | Deferred; no simulator/UI test yet | NOT_PROVEN |

## Commands and results

### Red focused

`xcodebuild test -project blnd_ios.xcodeproj -scheme blnd_ios -destination
"id=9EA58F59-CAD8-4FBF-9308-29711F6988E6"
-only-testing:blnd_iosTests/BlndIOSTests -quiet` — exit 2 in tmux session
`tv-ios-red`; build failed because `TVSearchResponse`, `MediaType`,
`MovieCard(mediaType:)`, and `isTV` did not exist. The first test commit also
needed `Foundation` imported for `Data` and `JSONDecoder`.

### Green focused

The same focused command in tmux session `tv-ios-green` compiled and passed
`BlndIOSTests` on iPhone 17 / iOS 26.5.

### Green broader

```
xcodebuild test -project blnd_ios.xcodeproj -scheme blnd_ios \
  -destination "id=9EA58F59-CAD8-4FBF-9308-29711F6988E6" \
  -only-testing:blnd_iosTests \
  -resultBundlePath /Users/jonathanyang/tmp/overnight/logs/tv-ios-verify.1791803090.xcresult \
  -quiet
```

Result summary from
`xcrun xcresulttool get test-results summary`: `Passed`; 4 passed, 0 failed,
0 skipped. Log: `/Users/jonathanyang/tmp/overnight/logs/tv-ios-verify.log`.
