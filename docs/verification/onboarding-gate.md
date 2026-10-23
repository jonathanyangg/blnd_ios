# Onboarding sign-up gate bounce (release blocker)

**Task:** signed-out new user: taste picks > Continue > app jumped back to Welcome (blank chevron screen), so nobody could finish onboarding. Fix test-first, make the repro a required Maestro flow, verify on one sim.

**Cause:** `OnboardingAccountGate` was a `NavigationStack` nested inside the onboarding screen that Welcome pushes onto its own stack. Showing it, and the `dismiss()` in the shared `BackButton`, popped the whole onboarding screen back to Welcome.

**Fix:** the gate is now inline (`blnd_ios/Views/Auth/OnboardingAccountGate.swift`), no nested stack. `AccountGateStage` (sign-up vs choose-username, back action) is a pure type. The chrome back chevron closes the gate first, then steps back through onboarding. Added accessibility ids to the sign-up form (`signup.name/username/email/password` and `signup.password.toggle`) and interactive keyboard dismissal.

## Evidence
- Red (before): `.maestro/12_signup_onboarding.yaml` on the old build ended on Welcome (`onboarding-gate/red.log`, `before-gate.png`).
- Unit tests: 192 passed, 0 failed (4 new in `OnboardingAccountGateTests`).
- Green (after): 12_signup_onboarding passed on one sim against the local backend: gate shown, account created, tutorial, home feed (`onboarding-gate/green2/.../takeScreenshot/12-1..12-5`).
- Required set now includes `11_onboarding_tour` and `12_signup_onboarding`.

## Not proven
- Real (non-local) backend sign-up, Sign in with Apple from the gate, and the choose-username branch end to end (unit-tested only).
- The flow reveals the password (eye toggle) before typing because iOS's Strong Password cover view swallows typing on a fresh simulator.
