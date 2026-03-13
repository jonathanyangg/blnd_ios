# BLND iOS Frontend — Security Audit Report

**Date**: 2026-03-09
**Scope**: All 57 Swift source files, Xcode project configuration, and `.gitignore`.

---

## No Critical or High severity issues found.

---

## Medium (4)

### 1.1. Keychain Items Lack Accessibility Attribute

- **Location**: `blnd_ios/Config/KeychainManager.swift:6-13`
- **Severity**: Medium
- **Description**: The `KeychainManager.save()` method does not set `kSecAttrAccessible`. Without this attribute, Keychain items default to `kSecAttrAccessibleWhenUnlocked`, which is reasonable, but the lack of an explicit setting means the app does not enforce `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — meaning tokens could be restored to a new device from an iCloud/iTunes backup.
- **Impact**: If a user's backup is compromised (e.g., an unencrypted iTunes backup extracted from their computer), the attacker gets valid JWT access/refresh tokens.
- **Fix**: Explicitly set `kSecAttrAccessible` to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` in the save query:
  ```swift
  kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
  ```

### 3.1. No Certificate Pinning

- **Location**: `blnd_ios/Networking/APIClient.swift:94`, `blnd_ios/Networking/AvatarUploader.swift:29`
- **Severity**: Medium
- **Description**: Both network call sites use `URLSession.shared` with no custom `URLSessionDelegate` for server trust evaluation. There is no certificate or public key pinning for the backend (`blnd-backend.onrender.com`) or Supabase (`wtnbecnjsougjjcplhqf.supabase.co`).
- **Impact**: A man-in-the-middle attacker on the same network (e.g., malicious Wi-Fi) who can install a rogue CA certificate on the device (or has access to a compromised CA) could intercept JWT tokens and all API traffic. Note: iOS's ATS already enforces TLS, so this requires a sophisticated attacker.
- **Fix**: Implement certificate pinning via a custom `URLSessionDelegate` or use a library like TrustKit. At minimum, pin the leaf or intermediate certificate for your backend.

### 6.1. Debug Logging of Raw API Responses in Production Builds

- **Location**: `blnd_ios/Networking/APIClient.swift:175-177`
- **Severity**: Medium
- **Description**: When JSON decoding fails, the app prints the raw response body (up to 500 characters) to the console:
  ```swift
  print("[APIClient] Decoding \(T.self) failed: \(error)")
  if let raw = String(data: data, encoding: .utf8) {
      print("[APIClient] Raw response: \(raw.prefix(500))")
  }
  ```
  These `print` statements execute in Release builds. While `print` on iOS goes to the system log (not visible to users directly), anyone with physical access to the device can read the console via Xcode/Console.app, and the log may contain sensitive response data.
- **Impact**: An attacker with physical device access (or malware with syslog access on a jailbroken device) could read API response payloads from the system log.
- **Fix**: Wrap all `print` statements in `#if DEBUG` blocks, or use `os.Logger` with appropriate privacy redaction.

### 8.1. Missing `PrivacyInfo.xcprivacy` Manifest

- **Location**: Project root — file does not exist
- **Severity**: Medium
- **Description**: Starting with iOS 17 and required as of Spring 2024, Apple requires a `PrivacyInfo.xcprivacy` file declaring the app's use of required reason APIs. The app uses `URLSession` (which accesses the network) and appears to access the photo library via `PhotosUI`. Without this manifest, Apple may reject App Store submissions.
- **Impact**: App Store rejection. Not a runtime vulnerability, but blocks distribution.
- **Fix**: Create a `PrivacyInfo.xcprivacy` file declaring:
  - `NSPrivacyAccessedAPITypes`: any required reason APIs used
  - `NSPrivacyCollectedDataTypes`: network activity data categories
  - `NSPrivacyTracking`: `false`

---

## Low (5)

### 1.2. Keychain Save Silently Ignores Errors

- **Location**: `blnd_ios/Config/KeychainManager.swift:12-13`
- **Severity**: Low
- **Description**: `SecItemAdd` returns an `OSStatus` that is never checked. If the save fails (e.g., Keychain is locked, device restrictions), the app silently continues as if the token was saved. On next launch, `AuthState.init()` will find no token and the user appears logged out.
- **Impact**: Users could silently lose their session. Not a direct vulnerability but degrades security diagnostics.
- **Fix**: Check the return status from `SecItemAdd` and log/handle failures.

### 1.3. Token Refresh Defined but Not Wired In

- **Location**: `blnd_ios/Networking/APIClient.swift:36-78` and `191-193`
- **Severity**: Low
- **Description**: The `TokenRefresher` actor exists and correctly serializes concurrent refresh attempts, but the `performRequest` method never calls it. When a 401 is received, it simply throws `.unauthorized` — the token refresh mechanism is defined but not wired into the request pipeline. The `AuthState.fetchCurrentUser()` catches `.unauthorized` and logs the user out.
- **Impact**: When the access token expires, the user is immediately logged out rather than transparently refreshing. The refresh token is stored but never used automatically. This means the refresh token persists in the Keychain longer than necessary without being rotated.
- **Fix**: In `performRequest`, when a 401 is received for an authenticated request, call `tokenRefresher.refresh()` and retry the request once. If the retry also fails with 401, then throw `.unauthorized`.

### 1.4. Password Held in Memory as Plain String

- **Location**: `blnd_ios/State/OnboardingState.swift:17`
- **Severity**: Low
- **Description**: The `OnboardingState` class holds the password as a plain `var password = ""` throughout the entire onboarding flow. The `reset()` method sets it back to `""` but does not zero the memory. Swift `String` is copy-on-write and the original buffer may remain in memory.
- **Impact**: On a jailbroken device, a memory dump could reveal the password. This is inherent to Swift's string handling and would require a jailbroken device to exploit.
- **Fix**: Call `reset()` promptly after signup completes (already done in `OnboardingCompleteView.submitAndFinish`). For defense in depth, consider using `Data` with zeroing, though this is difficult in pure SwiftUI.

### 6.2. Widespread Debug Print Statements Across Views

- **Location**: 23 `print` statements across the codebase
- **Severity**: Low
- **Description**: Error-case `print` statements throughout View files (e.g., `print("[ProfileView] loadWatched error: \(error)")`) persist in Release builds. These log error descriptions which could include server-returned messages.
- **Impact**: Information leakage through system logs. Less sensitive than the raw response logging in Finding 6.1 since these only log error descriptions, not full response bodies.
- **Fix**: Wrap in `#if DEBUG` or replace with `os.Logger`.

### 8.3. Privacy Settings Are Non-Functional Stubs

- **Location**: `blnd_ios/Views/Profile/PrivacySettingsView.swift:4-5`
- **Severity**: Low
- **Description**: The "Show Watch History" and "Appear in Search" toggles are local `@State` variables that reset when the view is dismissed. They are not persisted or sent to the backend. The text "Privacy settings coming soon" is shown. Users may believe their privacy preferences are being respected when they are not.
- **Impact**: Users may have a false sense of privacy control. Not a vulnerability per se, but a trust issue.
- **Fix**: Either implement the backend support and persist these settings, or remove the toggles entirely until they are functional.

---

## Informational

### Hardcoded API Base URL

- **Location**: `blnd_ios/Config/APIConfig.swift:5`
- **Description**: The base URL `https://blnd-backend.onrender.com` is hardcoded with no build-configuration-based switching (DEBUG vs RELEASE).
- **Fix**: Use `#if DEBUG` or xcconfig files to manage per-environment URLs.

### Supabase Project URL in Source

- **Location**: `blnd_ios/Config/SupabaseConfig.swift:4`
- **Description**: The Supabase project URL is hardcoded. However, the Supabase anon key is NOT present anywhere in the iOS codebase — all auth goes through the backend. The project URL alone is not a secret.

### No Jailbreak Detection

- **Description**: The app does not check for jailbroken devices. For a movie tracking app, this is generally not necessary — there is no DRM, financial transactions, or high-value target data.

---

## Key Positives

- Tokens stored in Keychain (not UserDefaults)
- No API keys or secrets embedded in the client
- Zero third-party dependencies (no supply chain risk)
- All network traffic uses HTTPS; no ATS exceptions
- No WebViews, custom URL schemes, or clipboard access
- No local database or cached PII on disk
- Good error handling that does not expose server internals to the UI
- Supabase anon key correctly kept server-side only
- Minimal PII collection (email, username, display name, avatar, ratings)

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 4 |
| Low | 5 |
| Informational | 3 |

## Priority Remediation Order

1. **Add `PrivacyInfo.xcprivacy`** — required for App Store submission (Medium #8.1)
2. **Set `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`** on Keychain items (Medium #1.1)
3. **Wrap `print` in `#if DEBUG`** across the codebase (Medium #6.1, Low #6.2)
4. **Wire up token refresh** in the request pipeline (Low #1.3)
5. **Consider certificate pinning** for backend and Supabase domains (Medium #3.1)
