# Feature: Letterboxd import in onboarding

Date: 2026-10-12 (extracted from the 2026-10-05 work, plus yes/no question)
Repository: `blnd_ios`
Branch: `feature/letterboxd-onboarding`
Status: `PARTIALLY_PROVEN`

Flow: … → OnboardingComplete → **"Do you use Letterboxd?"** → Yes: import instructions (Continue / Skip) → results → Find Friends; No: Find Friends.

## Acceptance criteria

| ID | Criterion | Test or evidence | Status |
| --- | --- | --- | --- |
| L-1 | After onboarding completion the user reaches the Letterboxd step instead of Find Friends. | `OnboardingCompleteView` appends `.letterboxdImport`; `onboardingImportRoutesToFindFriends` | `PARTIALLY_PROVEN` — route constant + launch-arg entry; full signup run not tested |
| L-2 | The step first asks "Do you use Letterboxd?". | XCUITest `LetterboxdOnboardingUITests` (asserts question text on entry); screenshot | `PROVEN` |
| L-3 | Yes shows the import instructions. | `testYesShowsImportInstructions` | `PROVEN` |
| L-4 | No continues to Find Friends. | unit `answeringNoToLetterboxdQuestionSkipsImport`; `testNoGoesToFindFriends` | `PROVEN` |
| L-5 | Skip / Done after import continue to Find Friends. | `AuthRoute.nextAfterLetterboxdImport` | `PARTIALLY_PROVEN` — route constant only; Done path not UI-tested |
| L-6 | App uploads the archive as authenticated multipart and decodes the summary. | `letterboxdImportUploadsMultipartAndDecodesSummary` (stubbed URLSession) | `PROVEN` |
| L-7 | Profile → Import (non-onboarding) is unchanged. | `ProfileView` still calls `ImportContextView()` → default `.instructions` | `NOT_PROVEN` by test (code inspection only) |

## Red/green evidence

Red (tests written first, before any implementation on this branch):

```sh
./scripts/verify.sh --log-dir ~/tmp/overnight/ios/logs --derived-data ~/tmp/overnight/ios/dd
```

Result: `FAIL` (exit 65) — `type 'AuthRoute' has no member 'nextAfterLetterboxdImport'`,
`extra arguments at positions #2, #3 in call` (injectable upload), `argument passed to call that takes no arguments` / `.question` (question state).

Green:

- `./scripts/verify.sh …` → exit 0; `blnd_iosTests` 3/3 passed.
- `xcodebuild … -only-testing:blnd_iosUITests/LetterboxdOnboardingUITests test` (iPhone 17 Pro sim) → exit 0, 2/2 passed.
- Mutation check: removing `viewState: .question` from `WelcomeView` makes both UI tests fail (exit 65); restored.

`scripts/verify.sh` is not on `origin/main` yet; it was run from an uncommitted local copy.

## Simulator/UI evidence

iPhone 17 Pro simulator, launch argument `UI_TEST_LETTERBOXD_IMPORT` (DEBUG only), opens the step directly.
Screenshot: `letterboxd-onboarding-question.png`. Accessibility ids: `import.question.yes`, `import.question.no`, `import.continue`, `import.skip`, `import.results`, `import.done`.

## Not proven

- Full signup → import XCUITest (needs auth fixtures + local API in app runtime).
- Real Letterboxd web export / live backend upload from the app.
- Physical device.
