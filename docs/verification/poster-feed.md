# Poster feed redesign (full-bleed poster, hold-to-play trailer, shared detail sheet)

## Mini paper
**Original task:** redesign the reel (non-grid) feed. Each card is a full-bleed poster with a translucent info
overlay. A tap fades the overlay. Press-and-hold plays the trailer, and a hold of 1s or more locks it on. Nothing
autoplays. A "Details" chip opens a shared detail bottom sheet, which grid and search taps also use. Swipes keep
their meaning. Trailers never use scraped streams. Playback stays cheap and safe. Also fix the white strip under
the first card.

**What was done**
- `ReelsFeedView`: each card is now exactly one page tall (`containerRelativeFrame`) instead of "height minus an
  80pt guess", and the scroll view runs behind the floating tab bar. This fixes the strip under the first card:
  the next card's top and the clipped white "Watch Now" button showed there. The info panel is padded clear of
  the tab bar. The detail push became `.sheet(MovieDetailSheet)`. Playback stops when scrolling starts, when the
  sheet opens, when the app goes to the background, and when leaving the tab (`isTabVisible`). The next card's
  native clip is resolved and warmed (`TrailerPreloadPolicy`); this is skipped in Low Power Mode.
- `ReelCardView` / `ReelCardSections`: the poster sits in an overlay so a `scaledToFill` image can no longer make
  the card wider than the screen. This was already happening on `dev`: "78% match" is cut off in the before
  shot. The translucent panel (`reel.info.overlay`) holds the title, match %, meta, genres, compact provider
  logos (where-to-watch, tap opens `StreamingSheet`), watched-by, watchlist, comments, stars, Watch Now,
  Details chip (`reel.detail.chip`) and Watched with. All the existing actions are kept.
- `ReelCardTrailer` (new): a UIKit `UILongPressGestureRecognizer` (0.25s) attached through
  `UIGestureRecognizerRepresentable`, so "began" and "released" are reliable inside the paging ScrollView.
  `TrailerHoldState` (a pure struct) decides play, lock, stop, or toggle overlay. A light haptic fires on hold
  start and a medium one on lock. While a trailer plays, a HUD (`reel.trailer.playing`) shows the mute toggle
  (`reel.sound.toggle`, muted by default) and a lock icon. If there is no trailer, the user gets a light haptic
  plus a "No trailer available" toast (`reel.trailer.unavailable`).
- `TrailerSource` (new): resolves native → YouTube → none, with an in-memory + UserDefaults cache.
- `TrailerPlayer`: now `@Observable`. It owns the single AVQueuePlayer (looping, muted) and the single reused
  YouTube WKWebView. It reports `isPlaying` from AVPlayer `timeControlStatus` or the iframe `onStateChange`, so
  the poster stays visible until frames arrive. It also handles mute/unmute and `preload(url:)`, which loads
  `isPlayable` metadata only.
- `MovieDetailSheet` (new): `NavigationStack { MovieDetailView }` in a `.large` sheet with a drag indicator
  (`detail.sheet`). It reuses every existing detail section: synopsis, cast, ratings, where to watch, friends'
  takes, comments, actions. FYP grid, Discover grid, the search poster grid and search movie rows now open this
  sheet instead of pushing `MovieDetailView`.
- Removed code that only the old 16:9 trailer used: the scrubber-zone swipe exclusion and `MediaBottomYKey`.

**Design decisions**
1. **Swipe up stays "next movie".** The feed is a vertical paging ScrollView, so a swipe-up gesture for details
   would fight paging and make "next" unreliable. Details open only from the chip, or by tapping a grid or search
   poster. Dragging the sheet down returns to the same poster at the same feed position, because the feed never
   leaves the screen.
2. **Trailer source, no scraping.** We never extract raw YouTube streams (YouTube ToS and App Review risk).
   (a) Native first: iTunes Search API `previewUrl`. The match requires `kind == feature-movie`, a normalized
   title that equals ours (case, diacritics and punctuation folded) and a release year within ±1. Results are
   cached per tmdbId for 7 days, including "no match". Network errors are not cached. Lookup is lazy: on hold,
   or when preloading the next card.
   (b) Fallback: the official YouTube iframe from `youtube-nocookie.com` with `controls=0, modestbranding=1,
   playsinline=1, rel=0, iv_load_policy=3, fs=0, disablekb=1, mute=1` (`YouTubeEmbed`), scaled to cover the card.
   (c) Otherwise: poster only, plus a haptic and a toast.
   As expected, iTunes finds few titles (it returned no results even for "Inception" during testing), so the
   iframe is the common path. YouTube is never preloaded.
3. **Full-bleed scope.** The poster is edge to edge and runs behind the floating tab bar. It does **not** go
   behind the status bar, because Home, Discover and Blend all keep their header (logo, search, filter, For
   You/Discover tabs) above the feed. Floating that header over the poster would change all three hosts and is
   left for a follow-up.
4. Playback stops on `scenePhase == .background`, not `.inactive`. With `.inactive`, Control Center or a system
   prompt would kill a locked trailer (seen in testing when the XCTest runner attached).
5. Reduce Motion: no overlay fade animation and no page scale effect.

## Acceptance
| # | Criterion | Evidence | Status |
|---|---|---|---|
| 1 | Full-bleed poster, translucent overlay, white strip under first card fixed | before-feed-first-card.png vs after-feed-first-card.png / after-feed-poster-card.png | PROVEN (edge to edge, behind tab bar) |
| 1b | Poster behind the status bar | header kept above the feed (decision 3) | NOT_PROVEN / not done |
| 2 | Tap fades overlay, tap restores | Maestro 06 steps (assertNotVisible / assertVisible `reel.info.overlay`), after-overlay-faded.png | PROVEN |
| 3 | Hold plays, release stops; ≥1s hold locks, tap stops; muted with sound toggle; no autoplay | `TrailerHoldStateTests` (6); Maestro 06 run 1: long press → `reel.trailer.playing` → tap `reel.sound.toggle` → tap → not visible; after-trailer-locked.png (YouTube playing, lock + muted icon) | PROVEN |
| 3b | Short hold (0.25s–1s) then release stops | unit test only; Maestro `longPressOn` always holds past 1s | PROVEN (unit) |
| 4 | Right swipe = Interested still works | Maestro 02_swipe_interested passes | PROVEN |
| 4b | Left swipe / swipe up unchanged | code path untouched (`horizontalSwipe`, paging); not run in Maestro | NOT_PROVEN (by run) |
| 5 | Details chip opens shared sheet; drag down returns to the same poster | Maestro 06 (`detail.sheet` visible, swipe down, same `reel.title` text visible); after-detail-sheet.png, after-detail-dismissed-same-card.png | PROVEN |
| 5b | Grid poster tap opens the same sheet | after-grid-mode.png → after-grid-detail-sheet.png | PROVEN |
| 5c | Search results open the same sheet | code change only; `05_search.yaml` fails on `dev` too (`search.result` id exists nowhere in the app) | NOT_PROVEN |
| 6 | Native → YouTube → none, matching, 7-day TTL incl. negative caching, no real network | `TrailerSourceTests` (8, stubbed fetch, isolated UserDefaults suites) | PROVEN (unit) |
| 6b | Native AVPlayer clip plays on device | no feed title resolved to an iTunes preview in this data set | NOT_PROVEN |
| 6c | YouTube fallback clean (no chrome, poster until playing) | after-trailer-locked.png | PROVEN (visual, simulator) |
| 6d | No-trailer toast | Maestro 06 run 2 took the `reel.trailer.unavailable` branch | PROVEN |
| 7 | Stop on scroll/page/sheet/background/tab, one player, Low Power no preload | `canPlay` wiring + `TrailerPreloadPolicyTests` (2) | PROVEN (unit) / background and Low Power NOT_PROVEN by run |
| 8 | Accessibility ids | all asserted in Maestro 06 except `reel.trailer.unavailable` (asserted via regex) | PROVEN |
| 9 | Dark theme, Reduce Motion | screenshots; reduce-motion code path not exercised | PARTIAL |

## Commands and results
Simulator `2DE0EE9C-899F-45F5-A275-F07AE0051FE5`, DerivedData `~/cursor-work/blnd-2.0-dd-f2`, local backend on :8000.

```
xcodebuild -project blnd_ios.xcodeproj -scheme blnd_ios -configuration Debug -destination id=$SIM \
  -derivedDataPath ~/cursor-work/blnd-2.0-dd-f2 API_BASE_URL=http://localhost:8000 build      # BUILD SUCCEEDED
xcodebuild ... test -only-testing:blnd_iosTests                                                 # TEST SUCCEEDED, 137 passed, 0 failed (119 before + 18 new)
maestro --device $SIM test -e EMAIL=$EMAIL_A -e PASSWORD=$PASSWORD .maestro/06_poster_feed.yaml  # pass (run 1: playing branch, run 2: unavailable branch)
maestro --device $SIM test -e EMAIL=$EMAIL_A -e PASSWORD=$PASSWORD .maestro/02_swipe_interested.yaml  # pass
maestro ... .maestro/05_search.yaml   # FAIL at `search.result` (already failing on dev: that id is not in the app)
```

Screenshots: `~/cursor-work/blnd-2.0-artifacts/poster-feed/`: `before-feed-first-card.png`, `after-feed-first-card.png`,
`after-feed-poster-card.png`, `after-overlay-faded.png`, `after-detail-sheet.png`, `after-detail-dismissed-same-card.png`,
`after-trailer-locked.png`, `after-grid-mode.png`, `after-grid-detail-sheet.png`. Only one "before" shot was taken
(the feed). The other before states were the old push-to-detail screens.

## Notes
- `02_swipe_interested.yaml` / `05_search.yaml` try to skip the tutorial with `reels.tutorial.skip`, but the real id is
  `reel-tutorial.skip`. This is not changed here; 06 uses the right id.
- The local data set has a duplicate "Inception" with no poster or trailer. It shows as a gradient card; this is data, not a regression.
- In the sheet, `MovieDetailView`'s back chevron closes the sheet (`dismiss`).
