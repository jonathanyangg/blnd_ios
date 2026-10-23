# Release prep (2.0)

- Version: `MARKETING_VERSION = 2.0`, `CURRENT_PROJECT_VERSION = 1000` for the app and ShareExtension (must match). Last known uploaded build in this repo's probes was 900; **confirm against App Store Connect before uploading**.
- Privacy manifest: added `DeviceID`, `ProductInteraction` (PostHog) and `PurchaseHistory` (RevenueCat); Contacts, Email, Phone, UserID, OtherUsageData already present. Tracking = false.
- APIConfig/RevenueCat: Release resolves to `https://blnd-backend.onrender.com` via build setting; RevenueCat debug logging is `#if DEBUG` only.
- `scripts/ExportOptions.plist` + `scripts/release.sh` (clean clone -> archive -> export; upload only behind `--upload`).
