# Maestro UI flows

Flows target `com.jonathan.blnd-ios` against the LOCAL backend on `http://localhost:8100` (see `TESTING.md` in the repo root).
Demo accounts are seeded locally: maya@blnd.local (blnd+), leo@blnd.local (blnd+, maya's friend), sam@blnd.local (free); password `Premium123!` (local seed only, not a secret).
Flows set these as `env` defaults; override with `-e EMAIL=... -e PASSWORD=...`.

Run: `tools/qa/run-flows.sh <sim name|udid> [out-dir] [glob]` (resets demo data before every flow, writes screenshots to `<out>/<flow>/takeScreenshot/` and `<out>/results.tsv`).

| Flow | Covers | Notes |
|---|---|---|
| 00_onboarding_partial | welcome, create account, pitch screens, taste picks | stops after the taste picks (Continue is tapped by 12_signup_onboarding) |
| 12_signup_onboarding | whole signed-out new-user path: 00 > Continue > inline sign-up gate > Sign Up > tour > home feed | real local backend; creates a throwaway account; regression for the nested-NavigationStack gate that bounced back to Welcome |
| 11_onboarding_tour | taste picks > swipe > rate > match > blends > find a movie > import > taste > friends > home feed | DEBUG mock host (-UITestScreen onboardTaste/onboardFeed), no backend needed; text taps because parent ids mask child ids |
| 10_solo_flow | solo search > detail > watchlist > rate | from feature branch, NOT required: fails on r7 because search "Inception" result 0 is not Inception (2010) so watch.hub never appears (live search order) |
| 01_sign_in_email | sign out, sign in as maya | |
| 02_swipe_interested | feed right swipe | toast is best-effort (2s), `.verify.sh` checks the DB row |
| 03_paywall_limits | free user paywall limits | as sam |
| 04_create_blend | create Blend with Leo | |
| 05_search | search "Inception" | |
| 06_poster_feed | poster overlay, detail sheet, trailer long-press | from feature branch |
| 07_recent_searches | recent searches, delete, clear all | from feature branch |
| 08_blend_find_movie | Blend with friend, find a movie, where to watch, rate | from feature branch, needs USERNAME_B (leo) |
| 09_empty_states | empty/error states | from feature branch, run as sam |
| 07_detail_where_to_watch | movie detail, where to watch | |
| 08_watchlist | add to watchlist | sheet rows are not in the accessibility tree, driven by coordinates (re-check if the sheet layout changes); `.verify.sh` checks the DB |
| 09_log_rate | star rating, Watched with | `.verify.sh` checks the rating row |

`<flow>.verify.sh` (optional) runs after a passing flow and must exit 0: it proves the server really saved what the UI showed.
`required.txt` lists the flows the PR gate requires.
Never store or commit real credentials.
