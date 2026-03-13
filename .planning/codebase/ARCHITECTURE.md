# Architecture

**Analysis Date:** 2025-02-20

## Pattern Overview

**Overall:** MVVM-ish layered architecture with @Observable state management

**Key Characteristics:**
- Views own local UI state, shared state injected via `.environment()`
- Domain-specific API enums (AuthAPI, MoviesAPI, etc.) delegate to singleton `APIClient`
- Keychain-backed authentication with Bearer token injection
- Composable state management: `AuthState` + `OnboardingState` + `TabState` as separate @Observable classes
- No third-party dependencies; uses native SwiftUI + async/await

## Layers

**UI/View Layer:**
- Purpose: SwiftUI view hierarchy with local state management
- Location: `blnd_ios/Views/`
- Contains: Tab-based navigation (Home, Friends, Groups, Profile), feature-specific views (Auth, Movies, Friends, Groups), shared components
- Depends on: State layer (via @Environment), Networking layer (via API enums), Theme/Config
- Used by: User interactions, lifecycle tasks

**State Layer:**
- Purpose: Shared observable state across the app (auth status, current user, tab selection, onboarding progress)
- Location: `blnd_ios/State/`
- Contains: `AuthState` (@Observable, login/logout/signup), `TabState` (@Observable, tab selection), `OnboardingState` (@Observable, credentials/genres/ratings cache)
- Depends on: Networking layer (for API calls), Keychain
- Used by: Views via `.environment()` injection

**Networking Layer:**
- Purpose: Domain-specific API abstractions with shared request/error handling
- Location: `blnd_ios/Networking/`
- Contains: `APIClient` singleton (HTTP + auth), domain enums (`AuthAPI`, `MoviesAPI`, `TrackingAPI`, `FriendsAPI`, `GroupsAPI`, `RecommendationsAPI`, `ImportAPI`, `AvatarUploader`)
- Depends on: Config (API base URL), Keychain (for Bearer token), Models
- Used by: State layer, Views (directly for API enums)

**Models Layer:**
- Purpose: Codable structs matching backend Pydantic schemas
- Location: `blnd_ios/Models/`
- Contains: `AuthModels` (SignupRequest, LoginResponse, UserResponse), `MovieModels` (MovieResponse, Genre, CastMember), `TrackingModels` (WatchedMovieResponse, WatchlistMovieResponse), `FriendModels` (FriendResponse, FriendRequestResponse), `GroupModels` (GroupResponse, GroupDetailResponse), `ImportModels` (LetterboxdImportResponse)
- Depends on: None
- Used by: Networking layer, State layer, Views for type safety

**Config/Infrastructure Layer:**
- Purpose: Runtime configuration and secure storage
- Location: `blnd_ios/Config/`
- Contains: `APIConfig` (base URL), `KeychainManager` (Security framework), `SupabaseConfig` (storage bucket name)
- Depends on: None (except Security framework)
- Used by: Networking layer (APIClient, AvatarUploader)

**Theme/UI Kit Layer:**
- Purpose: Centralized styling constants
- Location: `blnd_ios/Theme/`
- Contains: `AppTheme` (colors, corner radii, spacing, gradients)
- Depends on: None
- Used by: All views

## Data Flow

**Authentication Flow:**

1. User enters email/password on LoginView
2. View calls `authState.login()` → AuthAPI.login() → APIClient.request()
3. APIClient POST to `/auth/login`, receives LoginResponse
4. AuthState saves tokens to Keychain, sets `isAuthenticated = true`
5. ContentView detects `isAuthenticated == true`, gates to MainTabView
6. All subsequent requests inject Bearer token from Keychain via APIClient

**Onboarding Flow:**

1. User starts at WelcomeView (unauthenticated)
2. OnboardingView wraps NavigationStack with AuthRoute enum for step navigation
3. PickGenresView → RateMoviesView → SignUpView collect credentials + selections into OnboardingState (cached for back-nav)
4. SignUpView calls `authState.signup()` on step 3 (POST /auth/signup)
5. OnboardingCompleteView submits genres via PATCH /auth/profile + movie ratings via POST /tracking/ per movie
6. OnboardingState.reset() clears cache, AuthState.isAuthenticated set to true
7. ContentView gates to MainTabView, OnboardingView removed from navigation stack

**Movie Detail Load:**

1. User navigates to MovieDetailView with tmdbId
2. View fetches movie via MoviesAPI.getMovie(tmdbId)
3. Concurrently loads: watched status (TrackingAPI.getWatchedMovie), friends who watched (TrackingAPI.friendsWhoWatched), recommendations
4. Movie data populates display, rating shows if watched, "Rate" button shows if not

**State Management:**

- `AuthState`: Global auth context (login/signup/logout), user data, loading/error
- `TabState`: Shared tab selection (home/friends/groups/profile) + navigationReset counter for clearing NavigationStacks on tab switch
- `OnboardingState`: Temporary state cache during onboarding steps (genres, ratings, credentials), reset after signup
- `LocalState`: Component-level state (like `@State private var selectedTab` in HomeView) for UI toggles/tabs

## Key Abstractions

**APIClient (Singleton):**
- Purpose: HTTP request abstraction with Bearer token injection, error parsing, response decoding
- Examples: `blnd_ios/Networking/APIClient.swift`
- Pattern: Generic `request<T>()` and `requestVoid()` methods; all domain API enums delegate to shared instance

**Domain API Enums:**
- Purpose: Type-safe, domain-specific API wrappers (no auth concerns leaked into views)
- Examples: `blnd_ios/Networking/AuthAPI.swift`, `MoviesAPI.swift`, `TrackingAPI.swift`, `FriendsAPI.swift`, `GroupsAPI.swift`
- Pattern: Static functions returning strongly-typed responses, URL encoding/query params handled transparently

**Keychain Wrapper:**
- Purpose: Secure storage of access token, refresh token, user ID
- Examples: `blnd_ios/Config/KeychainManager.swift`
- Pattern: Simple enum with save/read/delete for String and Data

**@Observable Classes:**
- Purpose: Replace ObservableObject for simpler reactive state
- Examples: `AuthState`, `OnboardingState`, `TabState` in `blnd_ios/State/`
- Pattern: Classes annotated with @Observable, injected via .environment(), accessed via @Environment(Type.self)

**Shared Components:**
- Purpose: Reusable UI building blocks (buttons, avatars, cards, inputs)
- Examples: `AppButton`, `AvatarView`, `MovieCard`, `SearchBar`, `StarRatingInput` in `blnd_ios/Views/Shared/`
- Pattern: Lightweight SwiftUI Views with simple input parameters, no complex state

## Entry Points

**App Entry Point:**
- Location: `blnd_ios/App/blndApp.swift`
- Triggers: Application launch (marked with @main)
- Responsibilities: Initialize AuthState + OnboardingState, inject into environment, render ContentView

**Root Routing:**
- Location: `blnd_ios/Views/ContentView.swift`
- Triggers: AuthState.isAuthenticated changes
- Responsibilities: Gate between OnboardingView (unauthenticated) and MainTabView (authenticated)

**Tab Navigation Hub:**
- Location: `blnd_ios/Views/MainTabView.swift`
- Triggers: App launch after auth
- Responsibilities: 4-tab layout (Home, Friends, Groups, Profile), inject TabState into environment for child views

**Onboarding Navigation:**
- Location: `blnd_ios/Views/Auth/OnboardingView.swift` → `WelcomeView.swift`
- Triggers: Unauthenticated state
- Responsibilities: NavigationStack with AuthRoute enum, step-based flow (landing → genre pick → rate movies → signup → complete)

**Feature Screens:**
- HomeView: `blnd_ios/Views/Home/HomeView.swift` (FYP + Trending tabs, search, pull-to-refresh)
- FriendsListView: `blnd_ios/Views/Friends/FriendsListView.swift` (friends + pending requests, add friend sheet)
- GroupsListView: `blnd_ios/Views/Groups/GroupsListView.swift` (blend list, create group sheet)
- ProfileView: `blnd_ios/Views/Profile/ProfileView.swift` (user data, watched/watchlist grids, settings)

## Error Handling

**Strategy:** Centralized APIError enum with specific cases, local error state in views

**Patterns:**

- APIError cases: `.unauthorized`, `.badRequest(String)`, `.notFound`, `.rateLimited`, `.serverError(Int)`, `.decodingError`, `.networkError(Error)`
- APIClient maps HTTP status codes to APIError, parses Pydantic validation detail messages
- Views catch errors in task/async blocks, store in `@State private var errorMessage: String?`
- User-facing error text comes from `error.localizedDescription`
- Retry logic: Views show "Retry" button (e.g., MovieDetailView) to re-trigger task
- 404 handling: TrackingAPI.getWatchedMovie() catches .notFound and returns nil (movie not watched)
- Unauthorized (401): AuthState.fetchCurrentUser() catches .unauthorized and calls logout()

## Cross-Cutting Concerns

**Logging:** Console prints in APIClient for decode failures, no persistent logging framework

**Validation:**
- Email/password: Required fields checked before API call in LoginView/SignUpView
- Username: Checked for format (3-30 chars, a-z0-9._) by backend, error displayed in SignUpView
- Genre selection: Required before proceeding to rate movies in PickGenresView

**Authentication:**
- JWT stored in Keychain (accessToken, refreshToken, userId keys)
- Bearer token injected in all authenticated requests via APIClient
- Logout deletes all Keychain entries, sets AuthState.isAuthenticated = false
- Signup flow: Auth + onboarding (profile update + ratings) happen before marking authenticated

**Avatar Handling:**
- Upload: UIImage → JPEG → Supabase Storage POST (x-upsert to avatars/{userId}/avatar.jpg)
- Fetch: AsyncImage from public Supabase URL with cache-bust param (?v=timestamp)
- Display: AvatarView component with optional URL, gradient fallback

**Tab Navigation:**
- TabState.switchTab() increments navigationReset counter to reset NavigationStack IDs
- ProfileView taps on stats → tabState.switchTab(1 or 2) to jump to Friends/Groups tab

**Swipe-Back Gesture:**
- SwipeBackGestureModifier re-enables iOS edge swipe on views with hidden back button
- Applied to: MovieDetailView, FriendProfileView, GroupDetailView, Settings pages

---

*Architecture analysis: 2025-02-20*
