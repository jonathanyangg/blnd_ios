# Maestro UI flows

These flows target `com.jonathan.blnd-ios` and the local development backend.

1. Start the local backend on `http://localhost:8000`.
2. Build the Debug app for the simulator, replacing `<SIM>` with your simulator UDID:

```sh
xcodebuild -project blnd_ios.xcodeproj -scheme blnd_ios -configuration Debug -destination id=<SIM> -derivedDataPath build API_BASE_URL=http://localhost:8000 build
```

3. Install the built app:

```sh
xcrun simctl install <SIM> build/Build/Products/Debug-iphonesimulator/blnd_ios.app
```

4. Run all flows with environment variables for the demo account:

```sh
maestro test -e EMAIL=... -e PASSWORD=... .maestro/
```

Never store or commit credentials. Read them from a protected local artifact or export them in your shell session.

Note: the home feed’s right-swipe action labels its real feedback `Added to My Watchlist`. The onboarding tutorial separately explains that right means “Interested”; flow 02 asserts the home reel’s actual feedback.
