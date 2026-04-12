# App Store Submission History

Tracking rejections and resolutions across submissions so we don't repeat mistakes.

App ID: `6760280577`
Bundle ID: `com.jonathan.blnd-ios`

---

## Submission 3 — 2026-04-08 (Current — Unresolved)

**Submission ID:** `2099d8ee-60f9-4267-aaf3-227231bd789d`
**Device:** iPad Air 11-inch (M3)

### Issues

#### Guideline 2.3.3 — Screenshots
- **Problem:** 6.5" iPhone screenshots don't show current app UI. Showing splash/login screens or outdated UI instead of core features.
- **Fix:** Take fresh screenshots in simulator (iPhone 14 Plus or similar 6.5" device). Set `APIConfig.screenshotMode = true` first to blur copyrighted movie posters. Upload via App Store Connect → Previews and Screenshots → View All Sizes in Media Manager. Show FYP feed, reels, blends, profile — the core flows.

#### Guideline 5.1.2 — Privacy Data Use and Sharing
- **Problem:** App uploads user's Contacts to server but doesn't explicitly inform user or request consent before upload.
- **Fix (iOS):**
  - `FindFriendsView.swift`: Explicit text before permission prompt says *"Next, we'll ask permission to access your contacts. Phone numbers will be sent to blnd's server to find friends already on the app. We only store numbers that match existing users."*
  - `Info.plist` `NSContactsUsageDescription`: Updated to say *"blnd sends phone numbers from your contacts to our server to find friends already on the app. We only store numbers that match existing users."*
- **Important:** Must reconcile with Submission 2's rejection (see below) — NO skip button, button text must be "Continue" not "Find My Friends"/"Allow Access".

#### Guideline 2.3.6 — Age Rating
- **Problem:** Age rating descriptions didn't match app content. Needs "Frequent" for "Mature or Suggestive Themes".
- **Fix:** Updated age ratings in App Store Connect → App Information → Age Ratings. Current state: 15+/16+/18+ by region.

---

## Submission 2 — 2026-04-03 (Removed)

**Submission ID:** `a2091796-5ea6-4a43-b193-6d6ad3cc005f`
**Device:** iPad Air 11-inch (M3)

### Issues

#### Guideline 4.1(a) — Copycats
- **Problem:** Metadata includes content resembling popular movies without authorization. This is about the **screenshots** showing copyrighted movie posters/content.
- **Fix:** Use `APIConfig.screenshotMode = true` which blurs all TMDB posters via `.posterBlur()` modifier. Re-take screenshots with blur enabled.
- **Status:** Not resolved — Apple flagged this again implicitly through the outdated screenshots rejection in Submission 3.

#### Guideline 5.1.1(iv) — Privacy Data Collection (CRITICAL — CONTRADICTS SUBMISSION 3 FIX)
- **Problem:** Pre-permission consent screen had issues:
  1. Button labeled "Allow Access" — Apple says use "Continue" or "Next" instead
  2. Had a "Not Now" / skip button that let users bypass the system prompt
- **Apple's exact guidance:**
  > "A custom message appears before the permission request, and to proceed users press a 'Allow Access' button. Use words like 'Continue' or 'Next' on the button instead."
  > "A custom message appears before the permission request, and the user can close the message and delay the permission request with the 'Not Now' button. The user should always proceed to the permission request after the message."
- **Fix:**
  - Button text: **"Continue"** (not "Allow Access", "Find My Friends", or any action label)
  - **NO skip / "Not Now" button** — user always proceeds to system prompt
  - Opt-out happens at the iOS system permission prompt (tap "Don't Allow")
  - After system prompt (either allow or deny), flow always proceeds to `finish()`

---

## Submission 1 — 2026-03-22 (Removed)

**Submission ID:** `f6c5883d-4a62-4b0e-9b30-4acd923c52ad`
**Device:** iPad Air 11-inch (M3)

### Issues

#### Guideline 1.5 — Safety (Developer Information)
- **Problem:** Support URL was `https://github.com/jonathanyangg/blnd_privacy/settings/pages` which returns an error.
- **Fix:** Update Support URL in App Store Connect to a functional page. Current: `https://www.blnd.movie/support`.

#### Guideline 4.1(a) — Copycats
- Same issue as Submission 2 — movie content in screenshots without authorization.

#### Guideline 5.1.1(v) — Data Collection (Account Deletion)
- **Problem:** App supports account creation but doesn't offer account deletion.
- **Fix:** Add account deletion flow in Account Settings. Must be in-app (can't just require customer service).
- **Status:** ✅ Resolved. Present in `AccountSettingsView.swift:80` → calls `AuthState.deleteAccount()` → `AuthAPI.deleteAccount()`.

---

## Recurring themes / lessons learned

### Contacts permission flow is HIGHLY sensitive
- Must have clear text BEFORE permission prompt about server upload (5.1.2)
- Must NOT have skip button / action-labeled button (5.1.1(iv))
- Button text: "Continue" only
- User must always proceed to iOS system prompt
- `NSContactsUsageDescription` must mention server upload

### Screenshots — copyrighted movie content
- TMDB content is third-party — can't show in App Store screenshots without authorization
- Solution: `APIConfig.screenshotMode = true` blurs all movie posters via `.posterBlur()` modifier
- Always retake screenshots with this flag set to `true` before uploading

### Account deletion (Guideline 5.1.1(v))
- Must be in-app, not just "contact support"
- If not currently implemented, this will reject immediately

---

## Pre-submission checklist

Before every resubmission, verify:

- [ ] `APIConfig.baseURL = "https://blnd-backend.onrender.com"` (not localhost)
- [ ] `APIConfig.screenshotMode = true` when taking screenshots
- [ ] New screenshots uploaded for all required sizes (4.7", 5.5", 6.5", 6.7", iPad)
- [ ] Screenshots show core app flows (FYP, reels, blends, profile)
- [ ] `FindFriendsView` button label is "Continue" (not action-labeled)
- [ ] `FindFriendsView` has NO skip button before system prompt
- [ ] `FindFriendsView` text clearly states server upload
- [ ] `NSContactsUsageDescription` mentions server upload
- [ ] Account deletion exists in `AccountSettingsView`
- [ ] Support URL in App Store Connect is functional
- [ ] Age ratings reflect movie content (Mature Themes, Violence, etc.)
- [ ] Privacy labels in App Store Connect declare all data collection
