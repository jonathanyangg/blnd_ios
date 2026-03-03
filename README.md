# blnd iOS

Native iOS app for **blnd** — sync movie tastes with friends using AI recommendations.

## Features

- Sign up / log in with email
- Search movies (powered by TMDB)
- Track watch history and ratings
- Add friends and create watch groups
- AI-powered movie recommendations (personal + group)
- Import from Letterboxd

## Requirements

- Xcode 15+
- iOS 17.0+
- Running [blnd backend](../blnd_backend) at `http://localhost:8000`

## Setup

1. Open `blnd.xcodeproj` in Xcode
2. Start the backend: `cd ../blnd_backend && python -m uvicorn main:app --reload`
3. Run on simulator (iPhone 15/16)

## Architecture

- **SwiftUI** with `@Observable` state management
- **async/await** networking via `URLSession`
- **JWT auth** stored in Keychain
- Zero third-party dependencies
