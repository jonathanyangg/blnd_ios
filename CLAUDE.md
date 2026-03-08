# blnd iOS

SwiftUI iOS app for blnd — movie taste syncing with AI recommendations.

## Tech Stack

- Swift / SwiftUI, iOS 17+
- Zero third-party dependencies
- `@Observable` for state, `async/await` for networking
- Talks to FastAPI backend (not Supabase directly)

## Architecture

- **MVVM-ish**: Views own local state, shared state via `@Observable` + `.environment()`
- **Networking**: `APIClient` singleton → domain-specific static API enums (`AuthAPI`, `MoviesAPI`, `FriendsAPI`, `GroupsAPI`, etc.)
- **Auth**: JWT stored in Keychain, injected as Bearer token by `APIClient`
- **Onboarding nav**: `WelcomeView` owns a `NavigationStack(path:)` with `AuthRoute` enum; child views take `@Binding var path`. Signup API call happens on SignUpView (step 3), credentials collected last so duplicate email errors show immediately.
- **Onboarding state**: `OnboardingState` caches credentials + genres + ratings so back-navigation preserves selections. Genres submitted via `PATCH /auth/profile`, ratings via `POST /tracking/` per movie — both fire on OnboardingCompleteView "Let's go" tap.
- **Models**: Codable structs matching backend Pydantic schemas (snake_case → camelCase via CodingKeys)

## Project Structure

```
blnd_frontend/
├── App/
│   └── blndApp.swift          (BlndApp entry point, injects AuthState + OnboardingState into environment)
├── Config/
│   ├── APIConfig.swift         done base URL constant
│   └── KeychainManager.swift   done save/read/delete tokens via Security framework
├── Models/
│   ├── AuthModels.swift        done SignupRequest, LoginRequest, UpdateProfileRequest, LoginResponse, UserResponse, UserSearchResult, UserSearchResponse
│   ├── MovieModels.swift       done Genre, CastMember, MovieResponse (incl matchScore, trailerUrl), MovieSearchResult, RecommendedMovieResponse, RecommendationsResponse
│   ├── TrackingModels.swift    done TrackMovieRequest, WatchedMovieResponse, WatchlistMovieResponse, etc.
│   ├── FriendModels.swift      done SendFriendRequestRequest, FriendResponse, FriendRequestResponse, FriendListResponse, PendingRequestsResponse
│   └── GroupModels.swift       done CreateGroupRequest, AddMemberRequest, UpdateGroupRequest, GroupResponse, GroupDetailResponse, GroupMemberResponse, GroupRecMovieResponse, etc.
├── Networking/
│   ├── APIClient.swift         done singleton, request(), requestVoid(), Bearer token, notFound error
│   ├── AuthAPI.swift           done signup(), login(), me(), updateProfile(), searchUsers()
│   ├── MoviesAPI.swift         done search(), trending(), getMovie() + RecommendationsAPI
│   ├── TrackingAPI.swift       done trackMovie, getWatchHistory, getWatchedMovie, deleteWatchedMovie, addToWatchlist, removeFromWatchlist, getWatchlist
│   ├── FriendsAPI.swift        done listFriends, sendRequest, getPendingRequests, acceptRequest, rejectRequest, removeFriend
│   └── GroupsAPI.swift         done listGroups, createGroup, getGroup, updateGroup, deleteGroup, addMember, kickMember, leaveGroup, getRecommendations, getWatchlist, addToWatchlist, removeFromWatchlist
├── State/
│   ├── AuthState.swift         done @Observable, signup/login/logout/fetchCurrentUser
│   └── OnboardingState.swift   caches name/email/password/genres/ratings (tmdbId→liked) during onboarding
├── Theme/
│   └── AppTheme.swift
├── Views/
│   ├── ContentView.swift       done gates on authState.isAuthenticated
│   ├── MainTabView.swift
│   ├── Auth/
│   │   ├── WelcomeView.swift
│   │   ├── OnboardingView.swift
│   │   ├── SignUpView.swift    step 3: collects credentials, calls signup API, has email validation
│   │   ├── LoginView.swift     done wired to authState.login()
│   │   ├── PickGenresView.swift  done genre selection cached in OnboardingState
│   │   ├── RateMoviesView.swift  done swipe cards with real TMDB IDs, ratings cached in OnboardingState
│   │   └── OnboardingCompleteView.swift  done submits genres + ratings to API, then sets authenticated
│   ├── Home/
│   │   ├── HomeView.swift      done FYP + Trending tabs, match % badges on trending, pull-to-refresh
│   │   ├── SearchResultsView.swift  done fullscreen SearchView with live debounced search, auto-focus
│   │   ├── MovieDetailView.swift    done fetches by tmdbId, match score badge, tappable trailer, watched/unwatch/watchlist picker
│   │   └── RateMovieSheet.swift     done wired to POST /tracking/, half-star rating input, AsyncImage poster
│   ├── Friends/
│   │   ├── FriendsListView.swift    done real data, Friends/Requests tabs, accept/reject, pull-to-refresh
│   │   ├── FriendProfileView.swift  done real friend data, remove friend with confirmation
│   │   └── AddFriendView.swift      done Instagram-style live user search, send request inline
│   ├── Groups/
│   │   ├── GroupsListView.swift     done real data, member count + avatars, pull-to-refresh
│   │   ├── GroupDetailView.swift    done blend picks, group watchlist, members list, add member (friends picker sheet), edit group name
│   │   └── CreateGroupView.swift    done creates group via API, loading/error states
│   ├── Profile/
│   │   ├── ProfileView.swift   done real user data, watched/watchlist tabs with poster grids
│   │   ├── SettingsView.swift  done logout wired
│   │   └── Components/
│   └── Shared/
│       ├── AppButton.swift     (isLoading prop with spinner)
│       ├── MovieCard.swift     done AsyncImage poster support via posterPath prop
│       ├── SearchBar.swift
│       ├── AvatarView.swift
│       ├── GenrePill.swift
│       ├── TasteMatchBadge.swift
│       ├── StarRatingInput.swift   done interactive half-star rating + StarRatingDisplay read-only
│       ├── WatchlistPickerSheet.swift  done Spotify-style add to personal/group watchlists
│       └── OnboardingProgressBar.swift
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
- Auth, movies, recommendations, friends, groups endpoints are live
- For device testing: change APIConfig.baseURL to Mac's local IP, run backend with --host 0.0.0.0

## Backend Context

- Backend repo: ../blnd_backend/ (sibling directory)
- Backend CLAUDE.md: ../blnd_backend/CLAUDE.md (read for architecture/status)
- **OpenAPI spec**: `../blnd_backend/openapi.json` — auto-generated on every backend startup (always up-to-date). Read this file for the full API contract (endpoints, params, request/response schemas). Also available at http://localhost:8000/openapi.json when running.
- Endpoint source: ../blnd_backend/app/{domain}/views.py for route signatures
- Schemas: ../blnd_backend/app/{domain}/schemas.py for request/response models

## Design

- **Theme**: Dark monochrome, Cal.com/X aesthetic
- **Colors**: Black bg (#000), cards (#1A1A1A), borders (#2A2A2A), text (#FFF / #999 / #666)
- **No accent color** — movie posters provide all color
- **Typography-driven**: Big bold titles, whitespace, thin dividers
- **4 tabs**: Home (with search), Friends, Groups, Profile

## Screens (16 total)

- **Onboarding (4)**: Pick Genres → Rate Movies (swipe cards) → Create Account (signup API call) → You're In
- **Home (3)**: Home Feed, Search Results, Movie Detail
- **Friends (3)**: Friends List, Friend Profile, Add Friend
- **Groups (3)**: Groups List, Group Detail, Create Group
- **Profile (2)**: Profile, Settings
- **Shared (1)**: Rate Movie bottom sheet

## Completed

1. Convert Figma Make JSX exports to SwiftUI views -- all 16 screens built
2. Build foundation: APIConfig, KeychainManager, APIClient, AuthModels
3. Build auth flow: AuthState, onboarding views, ContentView auth gate
4. Build tab structure: MainTabView (Home, Friends, Groups, Profile)
5. Fix onboarding nav: NavigationPath-based routing, back buttons
6. Onboarding state caching: OnboardingState preserves genres/ratings across back-navigation
7. Reorder onboarding: Pick Genres -> Rate Movies -> Create Account (signup API) -> You're In
8. Email validation + password eye toggle on AppTextField
9. Movie models + networking: MovieModels, MoviesAPI, RecommendationsAPI
10. Home page: FYP + Trending tabs with real data, pull-to-refresh
11. Full-page search: SearchView with live debounced search (350ms), auto-focus
12. Movie detail: fetches by tmdbId, AsyncImage posters/backdrops, cast photos
13. MovieCard: AsyncImage poster support with gradient fallback
14. Tracking/watchlist API: TrackingModels, TrackingAPI (6 endpoints), APIClient requestVoid + notFound
15. RateMovieSheet wired to POST /tracking/ with loading/error states
16. MovieDetailView: watched status check, watchlist toggle, rating display
17. HomeView: TikTok-style underline tab picker, search icon → fullScreenCover
18. ProfileView: real user data, watched/watchlist poster grids from API
19. Watchlist endpoints moved to /watchlist/ (separate from /tracking/)
20. Friends feature: FriendModels, FriendsAPI (6 endpoints), FriendsListView (friends/requests tabs, accept/reject), AddFriendView (send by username), FriendProfileView (remove friend)
21. Groups feature: GroupModels, GroupsAPI (11 endpoints), GroupsListView (real data), GroupDetailView (blend picks + watchlist + members + add member), CreateGroupView (API wired)
22. Onboarding wiring: genres submitted via PATCH /auth/profile, movie ratings via POST /tracking/ per movie, RateMoviesView uses real TMDB IDs, OnboardingCompleteView submits before setting authenticated
23. MovieResponse: added matchScore field, match % badge on trending cards + movie detail, tappable trailer button via Link
24. AuthAPI: added updateProfile() for PATCH /auth/profile (display_name, taste_bio, favorite_genres)
25. Half-star ratings: StarRatingInput (interactive, 0.5 step) + StarRatingDisplay (read-only) components, RateMovieSheet updated
26. TMDB rating moved to meta row (year · runtime · ★ 4.4), backend already scales 0-10 → 0-5
27. Unwatch movie: DELETE /tracking/{tmdb_id}, confirmation dialog on MovieDetailView
28. Profile watched grid: half-star rating display (4.5 shows correctly)
29. Trending page: rank # top-left, match % top-right (separated)
30. Recommendations refresh: pull-to-refresh calls ?refresh=true to recalculate
31. AddFriendView: Instagram-style live user search (GET /auth/users/search?q=), debounced, inline "Add" buttons
32. GroupDetailView: edit group name (PATCH /groups/{id}, owner only), add member via friends picker sheet
33. WatchlistPickerSheet: Spotify-style "Add to Watchlist" — personal + all groups, checkbox toggles, batch save
34. GroupsAPI: updateGroup() for PATCH /groups/{id}, TrackingAPI: deleteWatchedMovie()

## Next Steps

35. Profile edit UI (display name, taste bio — backend already wired)
36. Re-rate a movie (PATCH /tracking/{tmdb_id})
37. Letterboxd import (POST /import/letterboxd — file upload in settings)
38. Polish: empty states, error handling

## Linting

- Pre-commit hooks: swiftlint + swiftformat + codespell
- Config: `.swiftformat` at repo root (maxwidth 120, trailing commas, `before-first` wrapping)
- swiftlint: type_name (uppercase start), cyclomatic_complexity (max 10), line_length (max 120), type_body_length (max 300)
- Use `case let .foo(bar)` not `case .foo(let bar)` (hoistPatternLet)
- Use `///` doc comments for API declarations, `//` for inline/property comments
- Use spaces around range operators (`200 ..< 300`)
- Number literals: 6+ digits need underscore grouping (e.g. `872_585`), 5 or fewer don't (e.g. `76341`)
- Computed properties: use multi-line bodies (swiftformat `wrapPropertyBodies` rule)
- Avoid multiline `if let` with brace on new line (swiftlint `opening_brace` conflicts); keep on single line when possible

## Last Updated

2026-03-07
