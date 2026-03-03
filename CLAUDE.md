# blnd iOS

SwiftUI iOS app for blnd — movie taste syncing with AI recommendations.

## Tech Stack

- Swift / SwiftUI, iOS 17+
- Zero third-party dependencies
- `@Observable` for state, `async/await` for networking
- Talks to FastAPI backend (not Supabase directly)

## Architecture

- **MVVM-ish**: Views own local state, shared state via `@Observable` + `.environment()`
- **Networking**: `APIClient` singleton → domain-specific static API enums (`AuthAPI`, `MoviesAPI`, etc.)
- **Auth**: JWT stored in Keychain, injected as Bearer token by `APIClient`
- **Models**: Codable structs matching backend Pydantic schemas (snake_case → camelCase via CodingKeys)

## Project Structure

```
blnd/
├── App/
│   └── blndApp.swift
├── Config/
│   ├── APIConfig.swift
│   └── KeychainManager.swift
├── Models/
│   ├── AuthModels.swift
│   ├── MovieModels.swift
│   ├── UserModels.swift
│   └── GroupModels.swift
├── Networking/
│   ├── APIClient.swift
│   ├── AuthAPI.swift
│   ├── MoviesAPI.swift
│   └── GroupsAPI.swift
├── State/
│   └── AuthState.swift
├── Views/
│   ├── Auth/
│   │   ├── WelcomeView.swift
│   │   ├── LoginView.swift
│   │   ├── SignUpView.swift
│   │   └── OnboardingView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── MovieDetailView.swift
│   │   └── Components/
│   ├── Friends/
│   │   ├── FriendsListView.swift
│   │   ├── FriendProfileView.swift
│   │   └── Components/
│   ├── Groups/
│   │   ├── GroupsListView.swift
│   │   ├── GroupDetailView.swift
│   │   └── Components/
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   ├── SettingsView.swift
│   │   └── Components/
│   └── Shared/
│       ├── AppButton.swift
│       ├── MovieCard.swift
│       └── SearchBar.swift
└── Extensions/
```

## Conventions

- Use `@Observable` (not `ObservableObject`)
- Use `async/await` (not Combine)
- Use `AsyncImage` for remote images
- Use Security framework for Keychain (not third-party)
- All API calls go through `APIClient.shared`
- Models use `CodingKeys` to map backend `snake_case` to Swift `camelCase`

## Backend

- Runs at `http://localhost:8000` (dev)
- Start with: `cd ../blnd_backend && python -m uvicorn main:app --reload`
- Auth endpoints are live; other domains return stubs

## Design

- **Theme**: Dark monochrome, Cal.com/X aesthetic
- **Colors**: Black bg (#000), cards (#1A1A1A), borders (#2A2A2A), text (#FFF / #999 / #666)
- **No accent color** — movie posters provide all color
- **Typography-driven**: Big bold titles, whitespace, thin dividers
- **4 tabs**: Home (with search), Friends, Groups, Profile

## Screens (16 total)

- **Onboarding (4)**: Create Account → Pick Genres → Rate Movies (swipe cards) → You're In
- **Home (3)**: Home Feed, Search Results, Movie Detail
- **Friends (3)**: Friends List, Friend Profile, Add Friend
- **Groups (3)**: Groups List, Group Detail, Create Group
- **Profile (2)**: Profile, Settings
- **Shared (1)**: Rate Movie bottom sheet

## Next Steps

1. Convert Figma Make JSX exports to SwiftUI views
2. Build foundation: `APIConfig`, `KeychainManager`, `APIClient`, `AuthModels`
3. Build auth flow: `AuthState`, onboarding views, `ContentView` auth gate
4. Build tab structure: `MainTabView` (Home, Friends, Groups, Profile)
5. Build movie features: `MovieModels`, `MoviesAPI`, `HomeView`, `MovieDetailView`
6. Build social: `FriendsListView`, `GroupsListView`, `GroupDetailView`
7. Build profile: `ProfileView` with user info + logout
8. Build recommendations: wire `RecommendationsAPI` into Home + Groups
9. Polish: empty states, error handling, search debounce

## Last Updated

2026-03-02
