# TestFlight / Production Checklist

Before pushing to TestFlight, verify the following:

- [ ] **APIConfig.swift** — Switch `baseURL` back to `https://blnd-backend.onrender.com`
- [ ] **Info.plist** — Remove `NSAppTransportSecurity` block (or delete the file entirely)
