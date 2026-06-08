# blnd+ Subscription — App Store Resubmission TODO

Tracking the fix for the App Review rejection of **iOS 2.0** (Submission `5748f1dc`),
which cited **Guideline 2.1(a)** (paywall "couldn't load" bug) and **Guideline 3.1.2(c)**
(missing subscription disclosures).

Root cause of the load bug: the **Paid Applications Agreement was never active**, so
StoreKit/RevenueCat returned no products → paywall showed "Could not load subscription
options."

---

## ✅ Done

- [x] **Paid Applications Agreement → Active** (Business → Agreements, Tax, and Banking)
  - [x] W-9 tax form submitted (Individual/Sole proprietor)
  - [x] Bank account added (Chase, USD)
  - This was the root cause of the 2.1 load bug. Fixes it at runtime for *any* build.
- [x] **In-app disclosure code** merged to `main` (`PaywallView.swift`)
  - title + price + length (`purchaseSection`), auto-renew terms + Terms of Use / Privacy
    Policy links (`legalSection`, commented "Guideline 3.1.2(c)")
- [x] **Terms of Use (EULA) link added to App Description** (metadata side of 3.1.2c) —
  standard Apple EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- [x] **Privacy Policy URL** already set in App Store Connect (`https://www.blnd.movie/privacy`)
- [x] **RevenueCat config verified correct** — bundle id `com.jonathan.blnd-ios`, valid
  In-App Purchase Key + App Store Connect API key, `default` offering (current) →
  `$rc_monthly` package → `blnd_premium_monthly` → `premium` entitlement
- [x] `Purchases.logLevel` bumped to `.debug` in `blndApp.swift:18` (revert before release)

---

## 🔒 Remaining (the actual blockers)

- [ ] **Archive & upload a NEW build from `main`.**
  - Build 7 (the binary Apple has) = commit `88cb559`, compiled BEFORE the disclosure
    code (`ffb7fcd`) was merged → its paywall has NO price/terms/privacy. Resubmitting
    it would fail 3.1.2(c) again.
  - Xcode → "Any iOS Device" → Product → Archive → Distribute App → App Store Connect → Upload.
  - ⚠️ Revert `Purchases.logLevel` to `.warn` (`blndApp.swift:18`) before archiving the
    release build.
- [ ] **Verify the paywall actually loads** (agreement is now Active).
  - Run on device/TestFlight; confirm the $4.99/mo option appears and a sandbox purchase
    completes. Watch the `.debug` RevenueCat logs.
- [ ] **Create the App Review submission with BOTH items.**
  - The last submission contained ONLY the app version — the subscription was missing.
  - App Review → new submission → add the new build AND `blnd_premium_monthly` (first
    subscription must be reviewed with the binary). This also clears the subscription's
    "Developer Action Needed" / "Rejected" leftover state.
- [ ] **Add a note + reply to Apple.**
  - In the submission's App Review Notes, state where the disclosures appear in the paywall.
  - Reply to Apple's rejection thread with a **screen recording** of the working purchase
    flow + visible price/terms/privacy (they marked it a bug-fix submission).

---

## Notes / reference

- App: blnd movies — Apple ID `6760280577`, bundle `com.jonathan.blnd-ios`
- Product: `blnd_premium_monthly`, group `blnd premium` (`22035493`), $4.99/mo
- RevenueCat project `6f8fa692`, app `app6b31fc4b68`
- Subscription "Developer Action Needed"/"Rejected" = leftover from the failed review;
  clears automatically when re-reviewed with the next submission (no separate edit needed).
