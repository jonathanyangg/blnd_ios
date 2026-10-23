# Recent searches + search UI cleanup — verification

## Original task

Add on-device **recent searches** to the Search screen and clean up the search UI:

1. `RecentSearchesStore` (`blnd_ios/Models/RecentSearches.swift`): UserDefaults JSON string array, newest first, case-insensitive de-dupe (re-search moves to top), trims whitespace, ignores queries < 2 chars, cap 10, remove one, clear all, injectable `UserDefaults`, no server calls.
2. UI: with an empty field, show "Recent searches" + "Clear all", clock-icon rows; tap = fill field and search now; trailing x removes one row. Record on submit (return key) or result tap. Clean states: clear (x) in field, keyboard dismissal on scroll, loading/empty/error states, AppTheme dark colors.
3. Accessibility ids: `search.recent.section`, `search.recent.item.<i>`, `search.recent.delete.<i>`, `search.recent.clearAll`.
4. Tests first (Swift Testing) + Maestro flow `07_recent_searches.yaml`.
5. Before/after screenshots, full unit target green, Maestro 05 + 07 pass.

## What was done

| Commit | Change |
|---|---|
| `9d805ca` | `RecentSearchesStore` (`@Observable`, `@MainActor`, ~40 lines) + `blnd_iosTests/RecentSearchesTests.swift` (8 tests). |
| `56e2628` | `SearchView`: recent section, `runSearch` (submit / recent tap skips the 350 ms debounce and records the query), `.submitLabel(.search)`, `search.clear` id + VoiceOver label on the field's x button (also refocuses), `.scrollDismissesKeyboard(.immediately)`, an error state shown when every search request fails. `UnifiedSearchResults`: spinner now shows on the *first* search (before, the "Search movies…" prompt stayed up while loading), `search.result` id on movie rows, `onSelectResult` callback recording the query on any result tap. New `.maestro/07_recent_searches.yaml`. |

The recent list shows when the field is empty (trimmed) and the store has items, outside the AI segment. With an empty store, the existing "Search movies, people, users, and blends" prompt shows. The AI segment does not record queries.

**Pre-existing bug found and fixed:** `05_search.yaml` asserted `id: search.result`, but no view set that id. On the baseline build, 05 failed at that step (`maestro-05-before.log`: `Assertion is false: id: search.result is visible`). The id is now on the movie result rows.

## Acceptance

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Cap 10, newest first | PROVEN | `newestFirstAndCappedAtTen` passed |
| 2 | Case-insensitive de-dupe moves to top | PROVEN | `caseInsensitiveDuplicateMovesToTop` passed; Maestro 07 step "tap item.1 → Inception becomes item.0" |
| 3 | Trims whitespace | PROVEN | `trimsWhitespace` passed |
| 4 | Ignores < 2 chars | PROVEN | `ignoresQueriesShorterThanTwoCharacters` passed |
| 5 | Remove one | PROVEN | `removesOneItem` passed; Maestro 07 `search.recent.delete.0` → "Inception" not visible, Dune remains |
| 6 | Clear all | PROVEN | `clearAllEmptiesStoreAndStorage` passed; Maestro 07 `search.recent.clearAll` → section not visible |
| 7 | Persists across store instances (same suite) | PROVEN | `persistsAcrossInstancesInSameSuite` passed; Maestro 07 Cancel → reopen search still lists both items |
| 8 | No network, on-device only | PROVEN | Store only imports Foundation and touches its `UserDefaults` (`storesOnlyAJSONStringArrayInDefaults` checks the stored payload is a plain JSON `[String]`); no API/URLSession reference in the file |
| 9 | Submit (return) records | PROVEN | Maestro 07: `pressKey: Enter` twice → items Dune(0), Inception(1) |
| 10 | Tap recent = fill + search immediately | PROVEN | Maestro 07: tap `search.recent.item.1` → `search.result` visible; `after-results.png` |
| 11 | Result tap records | NOT_PROVEN | Wired via `simultaneousGesture` on the results list. Builds, but no automated test taps a result and then checks the history |
| 12 | Accessibility ids | PROVEN | All four ids targeted by Maestro 07 (passed) |
| 13 | Clear (x) in field, keyboard dismiss on scroll, loading/error states | PARTIAL | x button proven (`search.clear` used in 07). Scroll-dismiss, first-search spinner and error state are in code and build, but no test exercises them (error state needs the backend down) |
| 14 | Full unit target green | PROVEN | 127 passed, 0 failed (was 119; +8 new) — `unit-tests.log`, `** TEST SUCCEEDED **` |
| 15 | Maestro 05 passes | PROVEN | `maestro-05-after.log` exit 0 (failed on baseline, see above) |
| 16 | Maestro 07 passes | PROVEN | `maestro-07.log` exit 0, all 27 steps COMPLETED |
| 17 | Before/after screenshots | PROVEN | `before-{empty-search,recent-list,results}.png`, `after-{empty-search,recent-list,results}.png`. The baseline has no recent list, so `before-recent-list.png` is the same screen as the empty search. An iOS "slide to type" keyboard tip appears in `after-recent-list.png`; it is system UI, not the app |

Artifacts live in `/Users/jonathanyang/cursor-work/blnd-2.0-artifacts/recent-searches/`.

## Commands and results

```sh
SIM=AE5D9438-0FFC-4EE8-B738-0057BCBED738
DD=/Users/jonathanyang/cursor-work/blnd-2.0-dd-f3
xcodebuild -project blnd_ios.xcodeproj -scheme blnd_ios -configuration Debug \
  -destination id=$SIM -derivedDataPath $DD API_BASE_URL=http://localhost:8000 build
# before: BUILD SUCCEEDED   after: BUILD SUCCEEDED
xcrun simctl install $SIM $DD/Build/Products/Debug-iphonesimulator/blnd_ios.app
xcodebuild ... test -only-testing:blnd_iosTests
# TEST SUCCEEDED — 127 passed, 0 failed
MAESTRO_DRIVER_STARTUP_TIMEOUT=180000 maestro --device $SIM test \
  -e EMAIL=$EMAIL_A -e PASSWORD=$PASSWORD .maestro/05_search.yaml
# baseline: FAILED (search.result missing)   after: exit 0
MAESTRO_DRIVER_STARTUP_TIMEOUT=180000 maestro --device $SIM test \
  -e EMAIL=$EMAIL_A -e PASSWORD=$PASSWORD .maestro/07_recent_searches.yaml
# exit 0
```

Notes: `MAESTRO_DRIVER_STARTUP_TIMEOUT` was needed because other Maestro sessions shared the machine and the first run hit "iOS driver not ready in time". On the very first baseline run, the iOS "Save Password?" sheet appeared after the sign-in subflow's optional "Not Now" tap and blocked `home.search`. A rerun, already signed in, went past it. That is a pre-existing flake in the sign-in subflow, left unchanged.
