# TestFlight / Production Checklist

Before pushing to TestFlight, verify the following:

- [x] **APIConfig.swift** — Switch `baseURL` to `https://blnd-backend.onrender.com`
- [x] **Info.plist** — No `NSAppTransportSecurity` block (already clean)
- [x] **PrivacyInfo.xcprivacy** — Added to project (email, phone, contacts, user ID, usage data, UserDefaults)
- [ ] **PrivacyInfo.xcprivacy** — Add to Xcode target (drag into project navigator or Build Phases → Copy Bundle Resources)
- [ ] **Push migrations** — `supabase db push` (actions_since_rebuild, missing indexes, phone/contacts)
