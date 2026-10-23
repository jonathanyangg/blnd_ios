# Staging build configuration

`Staging` is a Release-based build configuration whose `API_BASE_URL` is `https://blnd-backend-staging.onrender.com` (backend branch `dev`, separate Supabase project). Use the `blnd_ios Staging` scheme for device runs and TestFlight staging builds. `Debug` still targets the local server and `Release` still targets prod.

    xcodebuild build -project blnd_ios.xcodeproj -scheme "blnd_ios Staging" -destination 'generic/platform=iOS Simulator'
