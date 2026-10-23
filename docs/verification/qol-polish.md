# QoL + visual polish — verification

## Original task
Add haptics with a testable layer, reusable empty/loading/error state views with `state.*` accessibility ids,
dark-theme consistency fixes, light transitions, tests first, and a Maestro flow. Home feed, ReelCard*, MovieDetail*,
TrailerPlayer, Streaming/where-to-watch, Views/Groups and Search views were off limits because another worker is editing them.

## What was done
- `blnd_ios/Utils/Haptics.swift`: `Haptic` (.tap/.select/.success/.warning/.error) and a `HapticSink` protocol.
  `Haptics.sink` is swappable; the default `UIKitHapticSink` maps to Impact (light), Selection and Notification generators.
  `Haptic.refreshed(ok:)` picks success or error when a pull-to-refresh finishes.
- `blnd_ios/Views/Shared/StateViews.swift`: `LoadState.resolve(isLoading:error:isEmpty:)`, where loaded content always wins,
  so a refresh never blanks a list. Also `LoadingStateView` (`state.loading`) and `EmptyStateView(icon,title,message,actionTitle,action)` (`state.empty`).
  The existing `ErrorStateView(message, retry)` now carries `state.error` and `state.retry`.
- Three states wired into these screens:
  - Profile Watched + Watchlist grids. These had no error state before: failures were swallowed and showed as empty.
  - Diary (`WatchTimelineView`), Friends list (friends and requests tabs) and Notifications/Activity feed.
  - The ad-hoc private empty views in those files were removed.
- Haptics wired to:
  - Rating saved (`RateMovieSheet`) and watchlist add/remove (`WatchlistPickerSheet`).
  - Comment like: swapped the existing generator for `Haptics` in `MovieCommentsView+Data`.
  - Friend request sent (`AddFriendView`, `FriendProfileActions`) and accepted (`FriendsListView`, `ActivityFeedView`).
  - Tab switches (`MainTabView`), the Profile segment and the Friends segment.
  - Pull-to-refresh completion (Profile, Friends, Notifications).
  - Destructive confirmations: withdraw, remove friend, block and delete account.
- Dark theme:
  - Both `PaywallView` sheets now use `.presentationBackground(AppTheme.card)`.
  - The grep for `Color.white`/`.systemBackground`/`systemGray` backgrounds in allowed files only found intentional white capsule CTAs, so nothing changed there.
  - The app already forces `.preferredColorScheme(.dark)`.
  - `AppTheme` already had spacing tokens (`spacingXS…spacingHuge`); the new views use them.
- Transitions: accepted/declined requests animate out of the Notifications list, and the empty state fades in.
- Profile segment tabs have ids `profile.tab.<watched|diary|watchlist|taste>`.

## Acceptance
| Criterion | Status | Evidence |
|---|---|---|
| Haptics sink receives each event (injected recording sink) | PROVEN | `QoLPolishTests.sinkReceivesEachHaptic` ×5, `sinkReceivesHapticsInOrder` |
| `LoadState` mapping loading/empty/error/content | PROVEN | 4 `QoLPolishTests` cases |
| Full unit target green | PROVEN | 155 passed, 0 failed (`test-after.log`) |
| Watchlist shows `state.empty` | PROVEN | Maestro 09, `after-watchlist.png` |
| Friends + Requests show `state.empty` | PROVEN | Maestro 09, `after-friends*.png` |
| Diary leaves loading, no error | PROVEN | Maestro 09, `after-diary.png` |
| `state.error` + `state.retry` render and retry tap doesn't crash | PROVEN | Maestro 09 forced-error host (`-UITestScreen notificationsError`), `after-notifications-error.png` |
| `state.error` on real Watchlist/Diary with backend down | NOT_PROVEN | Would need the shared backend stopped; same `ErrorStateView` is proven above |
| Haptics physically fire at each call site | NOT_PROVEN | The simulator has no haptic engine; call sites are compile-checked only |
| Haptic on reel/feed rating and detail-page watchlist | NOT_PROVEN (deferred) | Those live in forbidden ReelCard*/MovieDetail* files; wire after the Home rewrite merges |
| No white strips in sheets | PROVEN (allowed files) | Paywall sheets set `presentationBackground`; grep found no white backgrounds |

## Commands
```
xcodebuild -project blnd_ios.xcodeproj -scheme blnd_ios -configuration Debug -destination id=$SIM \
  -derivedDataPath /Users/jonathanyang/cursor-work/blnd-2.0-dd-f6 API_BASE_URL=http://localhost:8000 build   # before: EXIT 0
... same ... test -only-testing:blnd_iosTests                                                              # ** TEST SUCCEEDED **, 155/0
xcrun simctl install $SIM <DerivedData>/Build/Products/Debug-iphonesimulator/blnd_ios.app
MAESTRO_DRIVER_STARTUP_TIMEOUT=180000 maestro --device $SIM test -e EMAIL=$EMAIL_A -e PASSWORD=... .maestro/09_empty_states.yaml  # all steps COMPLETED
```
Screenshots are in `blnd-2.0-artifacts/qol-polish/{before,after}-*.png`. Caveat: `before-watchlist.png` actually shows the Watched tab,
because the text tap hit the "Watchlist" stat label. The new `profile.tab.*` ids fix that for the after run.
