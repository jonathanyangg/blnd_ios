# Testing blnd iOS (testing-centric flow)

Goal: Jonathan reviews a one-page **mini paper with screenshots**, not code. Everything below runs on the Mac, nothing needs him except merging.

## Honest inventory (dev 217ecfd, measured 2026-10-23; backend half in blnd_backend/TESTING.md)
| Layer | Count | Result | Certainty |
|---|---|---|---|
| iOS unit (Swift Testing/XCTest, `blnd_iosTests`) | 108 | 108 pass on 3 consecutive runs, 0 skipped | CERTAIN: pure logic, URL strings only, one URLProtocol stub; only `RefreshSessionTests` (9) use tiny sleeps |
| XCUITest (`blnd_iosUITests`) | 10 | 9 pass, **1 FAIL** `NotesImportUITests.testReviewThenFound` ("import.notes.hit.129" not hittable) | the 9 passes are CERTAIN-ish (fresh launch, no network); the failure is real until investigated |
| Maestro UI flows | 10 flows | see table below | DOUBTFUL for anything touching the live TMDB feed and timing; each flow also has DB assertions where UI can't prove the result |

Maestro result (iPhone 17 Pro sim, local backend, latest run in `~/cursor-work/qa/artifacts/maestro-r4`):

| Flow | Run r4 | Seconds | Certainty |
|---|---|---|---|
| 00_onboarding_partial | PASS | 30 | certain up to the taste picks |
| 01_sign_in_email | PASS | 35 | certain (local backend, seeded user) |
| 02_swipe_interested | PASS | 48 | doubtful: live TMDB feed; DB-verified; passed 5 of 6 runs earlier with the 2 s toast (now optional) |
| 03_paywall_limits | PASS | 90 | good (passed in r3 and r4) |
| 04_create_blend | PASS | 94 | good (r3, r4) |
| 05_search | PASS | 37 | doubtful: live TMDB search (r3, r4 green) |
| 06_search_recent | FAIL | 67 | expected: feature not on dev; not in required.txt |
| 07_detail_where_to_watch | PASS | 32 | doubtful: live TMDB providers (r3, r4 green) |
| 08_watchlist | PASS | 113 | good: coordinate taps + DB-verified |
| 09_log_rate | PASS | 34 | good: DB-verified |

9 of 10 green; the 9 required flows are green in 2 consecutive full runs (r3 and r4) except 00 (new in r4, 1 pass plus 1 earlier).

Not covered at all yet: onboarding after the taste picks (swipe, rate, match, blends, now, letterboxd, taste, friends), sign up with a new account,
Blend invite acceptance from the invitee side, paywall purchase (StoreKit), push, Sign in with Apple, contacts. Treat these as UNVERIFIED.

## One-time setup (done on this Mac)
    brew install maestro      # already installed (2.11)
    cd blnd_backend && supabase start   # once; warm.sh up restarts Docker/containers afterwards

## Warm simulators (the "just let me look" setup)
    tools/qa/warm.sh up          # Docker + Supabase + seed + backend :8100 + boots blnd-warm-1/2/3 (9:41 status bar)
    tools/qa/warm.sh refresh     # build origin/dev, install on all 3 sims, sign in. ~5 min, run it after every merge
    tools/qa/warm.sh pr 52       # build PR #52 into its own sim "blnd-pr-52", signed in as maya, window opened
    tools/qa/warm.sh wt ~/cursor-work/blnd-2.0-f3   # same for a worktree, uncommitted work included: sim "blnd-wt-blnd-2.0-f3"
    tools/qa/warm.sh gc          # delete the per-PR / per-worktree sims
    tools/qa/warm.sh status | open [sim]
    tools/qa/warm.sh launchd-install   # keep it all up at login and every 10 min
Sim roles: `blnd-warm-1` maya (blnd+), `blnd-warm-2` sam (free, sees the paywall), `blnd-warm-3` leo (maya's friend, for Blends).
Each PR/worktree gets its own sim and its own derived data, so parallel reworks never overwrite each other. `make -f Makefile.qa <target>` wraps these.

## Mini paper per feature
    tools/qa/feature-paper.py --slug recent-searches --title "Recent searches" --task "..." --summary "..." \
        --after <flows out dir> --before <dev flows out dir> --flows-after <out>/results.tsv --unit-junit unit.xml
Writes `~/cursor-work/papers/<date>-<slug>/{index.html,summary.md}`: verdict (GREEN/RED/UNVERIFIED), original task, what changed,
test results, before|after screenshots per flow step, risks. `pr-check.sh` generates it automatically.

## PR gate (local, because macOS CI minutes are expensive)
    tools/qa/pr-check.sh <pr> [--no-post] [--merge]
Builds the PR on its own sim, runs unit tests + every flow in `.maestro/` from this checkout, builds the paper, and
posts commit status `blnd/local-qa` plus a PR comment (skip with `--no-post`). Required: unit tests + flows in `.maestro/required.txt`.
Merge: add label `automerge` to a PR into `dev` (or pass `--merge`); `.github/workflows/automerge.yml` squash-merges when `blnd/local-qa` is success.
`.github/workflows/promote.yml` opens "Release: dev into main" after each dev push (needs repo setting: Actions > "Allow GitHub Actions to create and approve pull requests").
`.github/workflows/ci.yml` is Ubuntu-only and cheap: validates Maestro YAML and blocks committed `.env`/credential files.

## Known limits
- The reel feed uses live TMDB through the local backend, so flows that start from the feed need internet.
- Flow runs take 30-150 s each on a loaded Mac (other agents share it).
- Add-to-Watchlist sheet and star rating have no accessibility ids, so flows use coordinates plus a DB check. Adding ids is a tiny feature-code change (not done here).
- `06_search_recent` fails until the recent-searches feature is on dev; update its ids/text then.
