# Solo flow: where-to-watch hub, tracking, post-watch log prompt (verification)

## Original task

"Solo flow: fast discovery, a prominent where-to-watch hub, tracking (watchlist/log/rate), and a post-watch log prompt." Discovery (the poster feed and search) was already done. This work covers the rest:

1. **Where-to-watch hub.** A prominent "Where to watch" section near the top of the detail sheet, grouped into Stream / Rent / Buy. Tapping a provider opens its deep link or web link through the existing `WatchLinkOpener`. Each Watchlist tile shows its top provider logos and a "Watch now" button, or "Not streaming right now" when there is no data. Provider data loads lazily per visible tile, is cached, and has a concurrency cap. ids: `watch.hub`, `watch.provider.<i>`, `watchlist.watchNow.<i>`.
2. **Tracking.** A compact action bar on the detail sheet: Watchlist toggle, Watched (marks the title watched and opens the rate sheet), and inline stars. ids: `detail.watchlist`, `detail.watched`, `detail.rate`.
3. **Post-watch prompt.** Opening a provider records a `PendingWatch` (newest only, expires after 12h, injectable clock and suite). On foreground, after `minElapsed` (20 min), ask "Did you watch <title>?" with three answers: Yes (rate and log), Not yet (snooze 2h, at most 2 prompts), No (clear). Never ask about a title that is already watched. The logic lives in the `PostWatchPrompt` struct.
4. Tests first (Swift Testing), plus a Maestro flow with a DEBUG-only `-pendingWatchDemo <tmdbId>` hook.

## What was done

| Commit | Change |
|---|---|
| `d031f79` | `blnd_ios/Models/SoloFlow.swift`: `PendingWatch`, `PendingWatchStore` (UserDefaults, 12h expiry, injected `now`), `PostWatchPrompt` (minElapsed / snooze / maxPrompts / already-watched check), the `WhereToWatch.hubOffers` / `topProviders(limit:)` helpers, and the `WatchProviderCache` actor (caches hits, shares in-flight requests, caps concurrent fetches at 3, does not cache failures). Also `blnd_iosTests/SoloFlowTests.swift` (15 tests). |
| `c191e58` | Detail: the hub now sits right under the title, meta and genres, in a card with STREAM / RENT / BUY headers. Opening a provider records a pending watch. A new action bar (Watchlist toggle with a long-press "Add to a blend watchlist" menu, and Watched) sits above the stars. The old "Watch Now + Watchlist" row and the "Watched with" row were removed. The rate sheet that "Watched" opens still has the watched-with picker. Watchlist status now loads from `/watchlist/status` (before, `isInWatchlist` was never initialised). Profile ▸ Watchlist tiles get `WatchlistHubRow`. `PostWatchPromptHost` is attached to `MainTabView`. `StreamingSheet` (feed and blend pick) records a pending watch too. New `.maestro/10_solo_flow.yaml`. |
| `98920f2` | Series are not recorded as pending watches, because the log prompt rates through the movie API. Maestro 10 now waits for the welcome screen. |
| `30ff1d0` | Watchlist "Watch now" stays on one line. |
| (this commit) | Maestro 10 answers any leftover prompt on first launch. This doc. |

How the prompt behaves:

- `next()` counts a prompt as shown when it returns one.
- Swiping the sheet away counts as "Not yet". After Yes or No the store is already empty, so the swipe does nothing.
- "Yes — rate it" clears the pending watch and swaps the sheet to the existing `RateMovieSheet`. That sheet saves through `TrackingAPI.trackMovie/updateRating`.
- The already-watched check uses `UserActionCache`, then falls back to `GET /tracking/{id}`.

## Acceptance

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Prominent hub near top of detail, Stream/Rent/Buy groups | PROVEN | `after-detail-hub.png` (hub directly under genres) vs `before-detail-hub.png` (hub below the fold). Maestro 10 asserts `watch.hub` and `watch.provider.0` |
| 2 | Stream before rent before buy; dedupe | PROVEN | `hubOrdersStreamThenRentThenBuyAndDedupesWithinGroup`, `topProvidersDedupeAcrossGroups` passed |
| 3 | Provider tap opens deep link / web via existing code | PROVEN (by reuse) | Calls the unchanged `WatchLinkOpener.open`. Not tapped in Maestro, because it leaves the app |
| 4 | Watchlist rows: top provider logos + "Watch now" | PROVEN | `after-watchlist.png` shows logos and Watch now on each tile |
| 5 | No N+1 storms: lazy per visible row, cached, capped concurrency | PROVEN | Loads in `.task` per `LazyVGrid` tile. `dedupesAndCapsConcurrency` (6 calls, 5 ids → 5 fetches, peak ≤ 2) and `failuresAreNotCached` passed |
| 6 | "Not streaming right now" when no data | NOT_PROVEN (UI) | Code path only. Both watchlist titles have providers, so no screenshot or Maestro step shows it |
| 7 | `watchlist.watchNow.<i>` opens provider + records pending | NOT_PROVEN (UI) | id is in the hierarchy. Tapping it leaves the app, so Maestro doesn't tap it |
| 8 | Action bar: watchlist toggle, Watched → rate sheet, inline stars | PROVEN | Maestro 10: `detail.watchlist`, then `detail.watched` (rate sheet appears), then star 4, Save, then `detail.rate.clear` visible (it only shows once a rating is saved). Backend `GET /tracking/27205` returned `rating = 3.5` (Maestro's tap landed on the left half of star 4) |
| 9 | PendingWatch store: record, newest-only, 12h expiry, clear | PROVEN | `recordsAndLoads`, `keepsNewestOnly`, `expiresAfterTwelveHours`, `clears` passed |
| 10 | Prompt policy: min elapsed (injectable), snooze 2h, max 2 prompts, already-watched suppress, expiry | PROVEN | `waitsForMinElapsed`, `minElapsedIsInjectable`, `snoozeRepromptsAfterTwoHours`, `stopsAfterTwoPrompts`, `neverPromptsForAlreadyWatched`, `noAndYesClear`, `expiredWatchNeverPrompts` passed |
| 11 | Prompt UI on foreground: Yes / Not yet / No | PROVEN | Maestro 10: launch with `-pendingWatchDemo 27205`, "Did you watch Inception?" shows, Not yet dismisses it. Relaunch, then Yes opens the rate sheet, Save. `after-post-watch-prompt.png`. The prompt was also seen re-asking an unanswered pending watch on the next launch, and not asking after the 2nd time |
| 12 | `-pendingWatchDemo` DEBUG only, absent from Release | PROVEN | The hook and its call are inside `#if DEBUG`. A Release build succeeded. `strings` on the Release binary finds 0 `pendingWatchDemo` (the Debug dylib has 2), while the prompt copy "Log it while it's fresh" is present (1) |
| 13 | Full unit target green | PROVEN | `** TEST SUCCEEDED **`, 175 unique test cases passed, 0 failed |
| 14 | Maestro 10 passes | PROVEN | Passed 3 times, including a rerun against already-watched or watchlisted state (`maestro-10.log`, `maestro-10-rerun.log`, `maestro-10-final.log`) |

## Commands and results

```
SIM=9B416FD5-FB4B-46BF-B7C4-B9F1E85BCA22
DD=/Users/jonathanyang/cursor-work/blnd-2.0-dd-f5

xcodebuild -project blnd_ios.xcodeproj -scheme blnd_ios -configuration Debug \
  -destination id=$SIM -derivedDataPath $DD API_BASE_URL=http://localhost:8000 build
# ** BUILD SUCCEEDED ** (base build for "before" shots, then after each change)

xcodebuild ... test -only-testing:blnd_iosTests
# ** TEST SUCCEEDED **, 175 unique cases, 0 failed (artifacts/solo-flow/unit-tests.log)

xcodebuild ... -configuration Release ... build
strings -a $DD/Build/Products/Release-iphonesimulator/blnd_ios.app/blnd_ios | grep -c pendingWatchDemo   # 0

xcrun simctl install $SIM $DD/Build/Products/Debug-iphonesimulator/blnd_ios.app
MAESTRO_DRIVER_STARTUP_TIMEOUT=180000 maestro --device $SIM test \
  -e EMAIL=$EMAIL_A -e PASSWORD=$PASSWORD .maestro/10_solo_flow.yaml
# exit 0
```

Screenshots are in `blnd-2.0-artifacts/solo-flow/`: `{before,after}-detail-hub.png`, `{before,after}-watchlist.png`, `{before,after}-post-watch-prompt.png`. The "before" prompt shot shows the plain feed, because the base app has no prompt. The screenshot helper flows are in `solo-flow/flows/`.

**Environment note:** between about 04:22 and 04:29 the local backend returned 401 for both test accounts, and a new signup failed too. It recovered by itself. Nothing in the app was changed for it.

## Known limits

- Only one sheet can be up at a time, so the prompt can't appear while another sheet (for example the detail sheet) is open. It shows on the next foreground.
- If the app is killed while the prompt is showing, that still counts as one of the 2 prompts, but no snooze is set. It asks again on the next launch, then stops.
- Swiping away the rate sheet after "Yes" loses the pending watch.
- The feed's `StreamingSheet` records without a poster path. The prompt doesn't show a poster, so nothing is lost today.
