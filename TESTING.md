# Testing blnd iOS (testing-centric flow)

Goal: Jonathan reviews a one-page **mini paper with screenshots**, not code. Everything below runs on the Mac, nothing needs him except merging.

## Honest inventory (iOS dev 8e7986d, backend dev 8defb27; measured 2026-10-23; live copy: ~/cursor-work/test-audit/CERTAINTY.md)
| Layer | Count | Result | Certainty |
|---|---|---|---|
| iOS unit (`blnd_iosTests`) | 167 | 167 pass, 0 fail, 0 skip (was 108 pass x3 on 217ecfd) | CERTAIN: fixtures + URLProtocol stub; RefreshSessionTests use tiny sleeps |
| XCUITest (`blnd_iosUITests`) | 10 (on 217ecfd, not re-run) | 9 pass, 1 FAIL `NotesImportUITests.testReviewThenFound` | failure real until diagnosed |
| Maestro | 13 flows | r5 + rerun: 13 of 13 green on the final flows (08_watchlist fixed after the sheet layout changed) | see below |

Maestro (iPhone 17 Pro clone `blnd-warm-1`, local backend, run r5 `~/cursor-work/qa/artifacts/maestro-r5`; screenshots in `<flow>/takeScreenshot/`):
00 onboarding partial, 01 sign in, 02 swipe (DB-verified), 03 paywall, 04 create blend, 05 search, 06 poster feed, 07 detail/where to watch, 07 recent searches, 08 blend find movie, 08 watchlist (DB-verified, green on rerun r6), 09 empty states, 09 log/rate (DB-verified).
Certain-ish: flows on seeded local data. DOUBTFUL (live TMDB / trailers / timing): 02, 05, 06, 07 detail, 08 blend find movie.
Each flow is green at least once on the current build; repetition counts are in CERTAINTY.md. Run each twice before calling it certain.

Not covered yet (UNVERIFIED): onboarding after the taste picks (screen rendered blank on 217ecfd), real sign up, invitee side of Blends, StoreKit purchase, Sign in with Apple, push.

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
- Flow numbers collide (two 07s, 08s, 09s) because feature branches add their own; names are unique, only the prefix repeats.
