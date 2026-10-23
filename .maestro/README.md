# Maestro UI flows

Flows target `com.jonathan.blnd-ios` against the LOCAL backend on `http://localhost:8100` (see `TESTING.md` in the repo root).
Demo accounts are seeded locally: maya@blnd.local (blnd+), leo@blnd.local (blnd+, maya's friend), sam@blnd.local (free); password `Premium123!` (local seed only, not a secret).
Flows set these as `env` defaults; override with `-e EMAIL=... -e PASSWORD=...`.

Run: `tools/qa/run-flows.sh <sim name|udid> [out-dir] [glob]` (resets demo data before every flow, writes screenshots to `<out>/<flow>/takeScreenshot/` and `<out>/results.tsv`).

| Flow | Covers | Notes |
|---|---|---|
| 00_onboarding_partial | welcome, create account, pitch screens, taste picks | stops after the taste picks (next step rendered blank on dev 217ecfd) |
| 01_sign_in_email | sign out, sign in as maya | |
| 02_swipe_interested | feed right swipe | toast is best-effort (2s), `.verify.sh` checks the DB row |
| 03_paywall_limits | free user paywall limits | as sam |
| 04_create_blend | create Blend, invite Leo | |
| 05_search | search "Inception" | |
| 06_search_recent | recent searches + clear | PENDING: fails until the recent-searches feature merges; not in required.txt |
| 07_detail_where_to_watch | movie detail, where to watch | |
| 08_watchlist | add to watchlist | sheet is not in the accessibility tree, driven by coordinates; `.verify.sh` checks the DB |
| 09_log_rate | star rating, Watched with | `.verify.sh` checks the rating row |

`<flow>.verify.sh` (optional) runs after a passing flow and must exit 0: it proves the server really saved what the UI showed.
`required.txt` lists the flows the PR gate requires.
Never store or commit real credentials.
