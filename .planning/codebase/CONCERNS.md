# Codebase Concerns

**Analysis Date:** 2026-03-12

## Tech Debt

**Refresh Token Not Implemented:**
- Issue: `refreshToken` is saved to Keychain in `AuthState` (signup/login) but never used. When JWT expires, APIClient will return `unauthorized` but there's no mechanism to refresh the token automatically or prompt the user to re-login gracefully.
- Files: `blnd_ios/State/AuthState.swift`, `blnd_ios/Networking/APIClient.swift`, `blnd_ios/Config/KeychainManager.swift`
- Impact: User will hit a hard 401 error and see an error message rather than a seamless re-auth experience. Long sessions or operations that take >1 hour will fail mid-flow.
- Fix approach: Implement token refresh in `APIClient` — when 401 occurs, attempt to refresh via backend `/auth/refresh` endpoint (if it exists), update Keychain with new token, retry the original request. If refresh fails, trigger logout and return to login screen.

**Error Handling via try? (Silent Failures):**
- Issue: 51 instances of `try? await` throughout the codebase silently swallow errors. Examples: `OnboardingCompleteView` (lines 80, 88) submit genres/ratings without surfacing failures, `WatchlistPickerSheet` catches errors and only prints to console, `AccountSettingsView` doesn't show upload failures to user.
- Files: `blnd_ios/Views/Auth/OnboardingCompleteView.swift`, `blnd_ios/Views/Shared/WatchlistPickerSheet.swift`, `blnd_ios/Views/Profile/AccountSettingsView.swift`, `blnd_ios/Views/Home/MovieDetailView.swift`, and 18 others
- Impact: Users won't know if critical operations failed (e.g., genre preferences not saved during onboarding, group member removal silently fails, avatar upload lost). Debugging is hard because errors only appear in console `print()` statements that get compiled out in release builds.
- Fix approach: Replace `try?` with proper `do/catch` blocks. Show toast errors or alert sheets for user-facing operations. Keep silent failures only for non-critical analytics/logging. Consider adding a shared error alert modifier to reduce boilerplate.

**Keychain userId as Empty String Fallback:**
- Issue: `GroupDetailView` (line 156) and `GroupMembersSheet` (line 19) retrieve userId via `KeychainManager.readString(key: "userId") ?? ""`. If Keychain read fails (corrupted, migrated app, etc.), code silently falls back to empty string.
- Files: `blnd_ios/Views/Groups/GroupDetailView.swift`, `blnd_ios/Views/Groups/GroupMembersSheet.swift`, `blnd_ios/Views/Profile/AccountSettingsView.swift`
- Impact: Empty userId will cause ownership/permission checks to fail silently. A user could see themselves as non-owner when they should be owner. Avatar upload in `AccountSettingsView` will upload to wrong path (`/avatar.jpg` instead of `/{userId}/avatar.jpg`).
- Fix approach: Create a computed property on a shared state object (or extend `AuthState`) to vend `currentUserId` as a non-optional String. If missing, force re-authentication. Alternatively, store userId in `@Environment` from root app and pass it down.

## Known Bugs

**Movie Discovery Endpoint Hardcoded to No Auth:**
- Symptoms: `RateMoviesView` calls `GET /movies/discover?genres=...` without authentication headers. Works fine in dev, but if backend ever requires auth for this endpoint, app breaks.
- Files: `blnd_ios/Views/Auth/RateMoviesView.swift` (line ~162), `blnd_ios/Networking/MoviesAPI.swift`
- Trigger: Change backend to require auth on discover endpoint.
- Workaround: Currently documented in CLAUDE.md that endpoint is unauthenticated (no auth required). If that changes, call will return 401.

**AsyncImage No Placeholder on Home/Profile:**
- Symptoms: Avatar images and movie posters blink/flash while loading because `AsyncImage` defaults to empty view until image arrives.
- Files: `blnd_ios/Views/Home/FriendsWhoWatchedSection.swift`, `blnd_ios/Views/Profile/ProfileView.swift` (poster grids), `blnd_ios/Views/Friends/FriendsListView.swift`
- Trigger: Any network delay (bad WiFi, high latency).
- Workaround: `AvatarView` has gradient fallback, but it's only used in some places. Movie `AsyncImage` in grids don't have fallback.
- Fix approach: Wrap all `AsyncImage` calls with `.redacted(reason: .placeholder)` or custom loading skeleton. Or use a shared AsyncImageWrapper component that always provides placeholder.

**WebView Download Interception Incomplete:**
- Symptoms: `WebView` (lines 98-140) sets up WKDownloadDelegate but may not handle all MIME types correctly. If Letterboxd changes its export format or Content-Type header, download capture breaks silently.
- Files: `blnd_ios/Views/Shared/WebView.swift`
- Trigger: Letterboxd changes export MIME type or adds new formats.
- Workaround: No user-facing error shown if download fails — just spinner spins forever.
- Fix approach: Add timeout to download. Detect if download never completes after N seconds and show error. Also consider detecting file extension as fallback if MIME type parsing fails.

## Security Considerations

**JWT Token in Keychain (Standard but Not Encrypted):**
- Risk: Keychain on iOS encrypts with device passcode/biometric, but if device is compromised, JWT can be extracted. No additional per-request signing.
- Files: `blnd_ios/Config/KeychainManager.swift`
- Current mitigation: iOS Keychain is inaccessible without device unlock. JWT has TTL (presumably).
- Recommendations: (1) Consider adding an extra layer: HMAC signing of requests with a locally-stored salt. (2) Add token expiration check before use — validate JWT exp claim in app before sending. (3) Never log tokens in print statements (currently safe — logs only show error messages, not token values).

**Supabase Public Storage Bucket Publicly Readable:**
- Risk: Avatar images are stored in a public bucket. Anyone can guess user IDs and download avatars. Not a major risk (avatars are meant to be public), but worth noting.
- Files: `blnd_ios/Networking/AvatarUploader.swift`, `blnd_ios/Config/SupabaseConfig.swift`
- Current mitigation: Public read access is intentional (avatars must display everywhere).
- Recommendations: None — this is by design. Just document that avatar paths should not be treated as secret.

**Email Exposed in SignUp Response:**
- Risk: Backend `LoginResponse` / `SignupResponse` includes user email in `UserResponse`. Email is sent in clear over HTTPS but could be logged or captured in memory dumps.
- Files: `blnd_ios/Models/AuthModels.swift` (UserResponse model)
- Current mitigation: HTTPS in transit. No place in app logs the entire user object.
- Recommendations: (1) Don't log entire `UserResponse` objects; only log safe fields like username. (2) Consider backend sending email only on `/auth/me` endpoint, not on signup response. (3) Client-side: zero out email from memory if not needed after login (low priority — iOS memory is isolated per app).

## Performance Bottlenecks

**WatchlistPickerSheet Loads All Groups on Every Sheet Open:**
- Problem: Sheet calls `loadState()` in `.task`, which fetches full groups list from backend even if user is just canceling without changing anything.
- Files: `blnd_ios/Views/Shared/WatchlistPickerSheet.swift` (lines 42, 185-200)
- Cause: No caching; always fetches fresh. No debounce.
- Impact: Slow UI responsiveness if user has 50+ groups. Extra network calls if sheet is opened/closed repeatedly.
- Improvement path: (1) Cache groups in parent View state or top-level @Observable. (2) Only refresh if user explicitly pulls-to-refresh. (3) Add loading skeleton so UI feels faster during fetch.

**Movie Posters Load One-by-One in Grids:**
- Problem: Each movie card in HomeView/GroupDetailView/ProfileView loads its poster image sequentially. No prefetch.
- Files: `blnd_ios/Views/Shared/MovieCard.swift`, `blnd_ios/Views/Home/HomeView.swift`
- Cause: `AsyncImage` by default doesn't prefetch.
- Impact: Scrolling feels janky; images appear after scroll settles.
- Improvement path: Use `URLSession` with prefetch hints, or implement progressive image loading (thumbnail first, then high-res).

**Onboarding Complete Loader Hardcoded 1-Second Sleep:**
- Problem: `OnboardingCompleteView` (line 95) sleeps for 1 second even if genre/rating submissions complete instantly. UX sees 3+ seconds of loader.
- Files: `blnd_ios/Views/Auth/OnboardingCompleteView.swift`
- Cause: Hardcoded delay to "let UI settle" — no actual progress tracking.
- Impact: Unnecessary wait time if backend is fast.
- Improvement path: Track number of pending requests; only sleep if all complete <500ms. Or show actual progress (3 of 4 steps submitted).

## Fragile Areas

**GroupDetailView and GroupMembersSheet Dual Ownership of Group State:**
- Files: `blnd_ios/Views/Groups/GroupDetailView.swift`, `blnd_ios/Views/Groups/GroupMembersSheet.swift`
- Why fragile: `GroupDetailView` owns `@State var group: GroupDetailResponse?`. `GroupMembersSheet` receives `@Binding var group` and modifies it. If sheet modifies group while main view is also fetching, race condition occurs. `@Binding` updates are not thread-safe with concurrent async operations.
- Safe modification: (1) Make sheet a sub-view of GroupDetailView instead of separate sheet, or (2) Pass a callback for modifications and re-fetch full group state in main view, or (3) Use `@StateObject` + `MainActor` to ensure all mutations happen on main thread (they likely already do, but not explicitly marked).

**CastSectionView ForEach with Array Index:**
- Files: `blnd_ios/Views/Shared/CastSectionView.swift` (comment indicates this was a fix for nil ID crash)
- Why fragile: Using array index as ForEach id. If cast list reorders (backend returns different order), SwiftUI will get confused about which view corresponds to which cast member. Could cause animation glitches or state leakage.
- Safe modification: If cast members have a stable ID (e.g., TMDB person_id), use that instead. If not available, add it to backend schema.

**WatchlistPickerSheet hasChanges Logic:**
- Files: `blnd_ios/Views/Shared/WatchlistPickerSheet.swift` (lines 22-28)
- Why fragile: hasChanges is computed by comparing `personalChecked` and `groupChecked` dicts to `initialPersonal` and `initialGroupState`. If a group is deleted server-side after sheet loads, the diff calculation could include groups that no longer exist, causing a confusing state.
- Safe modification: Validate that all groups in `groupChecked` still exist in fetched list before computing diff. Or reset diff if group list changes.

**Avatar Upload Path Uses userId from Keychain:**
- Files: `blnd_ios/Views/Profile/AccountSettingsView.swift` (lines 174-180)
- Why fragile: `userId` is read from Keychain, passed to `AvatarUploader.upload()`. If userId is nil/empty, upload path becomes invalid. No validation.
- Safe modification: (1) Ensure userId is non-null by storing in `@Environment` at app root. (2) Add guard with user-facing error if userId missing. (3) Consider storing userId in `AuthState` as non-optional property.

**ImportContextView WebView Data Capture Race:**
- Files: `blnd_ios/Views/Import/ImportContextView.swift` (lines 46-59)
- Why fragile: `.onChange(of: capturedZipData)` triggers upload, but if user dismisses the view before upload completes, `uploadTask` may not be properly canceled. WebView background task could continue running and modify state after view is gone.
- Safe modification: (1) Add explicit `@State private var uploadTask: Task<Void, Never>?` and cancel it in `onDisappear` (looks like code already does this at line 58 — good). (2) Test dismissal during upload to ensure no crashes.

## Scaling Limits

**No Pagination on Friends/Groups Lists:**
- Current capacity: HomeView, FriendsListView, GroupsListView all fetch entire lists at once (no `?limit=50&offset=0`).
- Limit: If user has 1000+ friends or groups, initial load will be slow and memory-heavy. Backend may timeout or return huge JSON.
- Scaling path: (1) Implement pagination in backend (add limit/offset params). (2) Update FriendResponse, GroupResponse models to support cursors. (3) In views, lazy-load more items on scroll. Consider using SwiftUI's `.onAppear` at end of list to trigger pagination.

**No Search Result Pagination (Live Search):**
- Files: `blnd_ios/Views/Home/SearchResultsView.swift`
- Current capacity: Debounced search returns all results matching query.
- Limit: If user has 10,000 movies in watchlist and searches "the", backend could return 1000 results; app shows all at once.
- Scaling path: Add `?limit=20&offset=0` to search endpoint. Implement lazy loading of additional results as user scrolls.

**Movie Discover Endpoint No Limit Check:**
- Files: `blnd_ios/Views/Auth/RateMoviesView.swift`
- Current capacity: Fetches top 10 movies per genre, max ~50 movies for 5 genres. Fine for small genre sets.
- Limit: If user selects 20+ genres, backend could return 200+ movies. Swipe card scrolling becomes slow.
- Scaling path: Hardcap at top 5 movies per genre max, or add `?limit=50` total param to discover endpoint.

## Dependencies at Risk

**No Version Pinning for iOS SDK:**
- Risk: App uses iOS 17+ APIs (e.g., `@Observable`, `async/await`) with no minimum version enforcement in Xcode project.
- Impact: If someone compiles with Xcode 15.0 targeting iOS 16, app will crash on launch due to missing symbols.
- Migration plan: Ensure Xcode project explicitly sets `IPHONEOS_DEPLOYMENT_TARGET = 17.0` in build settings. Add comment in CLAUDE.md.

**Supabase URLs Hardcoded:**
- Risk: `SupabaseConfig.projectURL` and `APIConfig.baseURL` are hardcoded. No way to switch environments without recompile.
- Impact: Cannot easily test against staging backend or self-hosted Supabase. Requires code change for each environment.
- Migration plan: (1) Move URLs to a `Config.xcconfig` file or environment variables. (2) Or use build schemes to inject different values. (3) Or accept that URLs are hardcoded and update CLAUDE.md to document the switch process.

## Missing Critical Features

**Refresh Token Not Used:**
- Problem: Backend likely returns both `accessToken` (short-lived, e.g., 15 min) and `refreshToken` (long-lived, e.g., 7 days). App saves both but never calls refresh endpoint.
- Blocks: Long-running background operations, multi-hour sessions, offline-then-online scenarios.

**No Offline Support:**
- Problem: App has zero offline caching. If user goes offline mid-session, any new data fetch fails immediately.
- Blocks: Mobile users on flaky connections, transit scenarios.

**No Analytics Integration:**
- Problem: App has no event tracking. Can't measure which features are used, where users drop off.
- Blocks: Product decisions, debugging user-reported issues.

## Test Coverage Gaps

**No Unit Tests:**
- What's not tested: All networking (`APIClient`, `AuthAPI`, `MoviesAPI`, etc.), all state management (`AuthState`, `OnboardingState`, `TabState`), all model decoding (CodingKeys, edge cases).
- Files: All files in `blnd_ios/Networking/` and `blnd_ios/State/`
- Risk: Refactors to state management or error handling could silently break logic. CodingKeys mismatches with backend go undetected until user sees wrong data.
- Priority: **High** — State and networking are the app's critical paths.

**No Integration Tests:**
- What's not tested: Full auth flow (signup → pick genres → rate movies → complete), watchlist operations across personal + groups, friend request lifecycle.
- Risk: Backend schema changes could break flows mid-user journey without detection.
- Priority: **High** — These are complex, multi-step flows.

**No UI Tests (XCUITest):**
- What's not tested: Navigation (tab switching, back buttons), form validation, error alerts, loading states.
- Risk: Regression in UI interactions go unnoticed (e.g., back button stops working, alert doesn't show).
- Priority: **Medium** — Lower risk than networking but good for confidence.

**AccountSettingsView Avatar Upload Not Tested:**
- Files: `blnd_ios/Views/Profile/AccountSettingsView.swift`
- Untested: Photo picker selection, JPEG compression, Supabase upload (network error, timeout), profile update after upload success.
- Risk: Avatar upload could fail silently due to network error. User sees "Uploading..." forever.
- Priority: **High** — User-facing critical feature.

**Onboarding Flow Not Tested:**
- Files: `blnd_ios/Views/Auth/SignUpView.swift`, `blnd_ios/Views/Auth/PickGenresView.swift`, `blnd_ios/Views/Auth/RateMoviesView.swift`, `blnd_ios/Views/Auth/OnboardingCompleteView.swift`
- Untested: Duplicate email handling, backend validation errors, network failures mid-flow, back-navigation state preservation.
- Risk: Users hit unhelpful error messages or lose progress.
- Priority: **High** — Onboarding is the first experience.

---

*Concerns audit: 2026-03-12*
