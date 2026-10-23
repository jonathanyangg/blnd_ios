# Release prep (release name "2.0", App Store version 8)

- Version: `MARKETING_VERSION = 8`, `CURRENT_PROJECT_VERSION = 1000` (the product is called "2.0" in release notes only; App Store Connect had already closed the 2.0 train and used versions up to 7, upload of 2.0 failed with errors 90062/90478/90186. Past versions: 2.0, 3.0, 4.0, then 5, 6, 7) for the app and ShareExtension (must match). Last known uploaded build in this repo's probes was 900; **confirm against App Store Connect before uploading**.
- Privacy manifest: added `DeviceID`, `ProductInteraction` (PostHog) and `PurchaseHistory` (RevenueCat); Contacts, Email, Phone, UserID, OtherUsageData already present. Tracking = false.
- APIConfig/RevenueCat: Release resolves to `https://blnd-backend.onrender.com` via build setting; RevenueCat debug logging is `#if DEBUG` only.
- `scripts/ExportOptions.plist` + `scripts/release.sh` (clean clone -> archive -> export; upload only behind `--upload`).
