# Remove "Watch Tonight" (Home "Find a movie now" entry)

## Mini paper
**Original task:** remove the Watch Tonight feature with no dead code or broken navigation.
**Interpretation:** no literal "Watch Tonight" exists in the iOS app. The only matching feature is the Home
"Find a movie now" one-pick entry (backed by `/recommendations/now`; the backend `pick-tonight` endpoints are not
called by iOS). The Home button and its full-screen cover are removed. `FindMovieNowView` is kept because onboarding v2
uses it as its first-pick step (changing onboarding is out of scope). Blend picking will use group recommendations instead.
**Also fixed:** a duplicated `CatalogFilterButton` row on Home (merge artifact) shown as two "All" chips.
**Maestro:** all flows used the removed `find-movie-now.entry` as their "home is ready" signal; they now use `home.search`.

## Acceptance
| Criterion | Evidence | Status |
|---|---|---|
| Home has no Find-a-movie-now button | before/after screenshots | PROVEN |
| App builds, no broken nav | Debug build, Maestro `04_create_blend` passes on iPhone 17 Pro sim | PROVEN |
| Home shows one filter chip | after-home.png | PROVEN |
| Onboarding pick step still works | unchanged; `NowPickTests` pass | PROVEN (unit) |

Screenshots: `~/cursor-work/blnd-2.0-artifacts/remove-watch-tonight/{before,after}-home.png`
