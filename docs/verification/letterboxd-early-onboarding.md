# Letterboxd import moved earlier in onboarding

Change: the optional import step now comes right after "loved" + account creation (step 4 of 11, was 9),
is titled "Import from Letterboxd", and is no longer a tutorial step, so Skip advances to the tutorial instead of jumping to friends.

| Criterion | Test | Result |
|---|---|---|
| Import follows loved/account | OnboardingStepOrderTests.letterboxdImportComesRightAfterLovedAndAccount | red (no `afterAccount`) → green, PROVEN |
| Optional, not tutorial | OnboardingStepOrderTests.letterboxdImportIsOptionalNotTutorial | green, PROVEN |
| UI: Continue from loved shows "Import from Letterboxd"; Skip → "Swipe it" | LetterboxdEarlyOnboardingUITests | red (build) → green, PROVEN |
| Hub still works | LetterboxdOnboardingUITests (3) | green, PROVEN |
| Real account-gate path (signed-out) lands on import | not automated (needs auth) | NOT_PROVEN |

Full unit suite: 194 passed; 1 failure is the known clock flake fixed separately in PR #56.
