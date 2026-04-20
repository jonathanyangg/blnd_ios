# blnd iOS

SwiftUI iOS app for blnd — movie taste syncing with AI recommendations.

## Tech Stack

- Swift / SwiftUI, iOS 17+
- `@Observable` for state, `async/await` for networking
- Talks to FastAPI backend for API, Supabase Storage for avatar uploads
- PostHog iOS SDK (`posthog-ios`) for product analytics

## Architecture

- **MVVM-ish**: Views own local state, shared state via `@Observable` + `.environment()`
- **Networking**: `APIClient` singleton → domain-specific static API enums (`AuthAPI`, `MoviesAPI`, `FriendsAPI`, `GroupsAPI`, etc.)
- **Auth**: JWT stored in Keychain, injected as Bearer token by `APIClient` and Supabase Storage uploads
- **Avatars**: Upload JPEG to Supabase Storage (`avatars/{user_id}/avatar.jpg`), get public URL with cache-bust param (`?v=<timestamp>`), save via `PATCH /auth/profile { avatar_url }`. `AvatarView` renders actual image via `AsyncImage` when URL is present, gradient fallback otherwise.
- **Tab navigation**: `TabState` (@Observable) injected from `MainTabView`, allows any child view to switch tabs (e.g. ProfileView stats → Friends/Groups tab). `pendingRequestCount` drives badge on Friends tab, refreshed on launch + tab switch + accept/reject.
- **UserActionCache**: Singleton in-memory cache of watched movies (ratings) + watchlisted IDs. Bootstrapped on login (fetches full history). Updated inline on rate/watchlist/unwatch actions. Eliminates redundant API calls for status checks. Reset on logout.
- **Swipe-back**: `SwipeBackGestureModifier` re-enables iOS edge-swipe dismiss on views that hide the navigation back button
- **Onboarding nav**: `WelcomeView` owns a `NavigationStack(path:)` with `AuthRoute` enum; child views take `@Binding var path`. Signup API call happens on SignUpView (step 3), credentials collected last so duplicate email errors show immediately.
- **Onboarding state**: `OnboardingState` caches credentials + genres + ratings so back-navigation preserves selections. Genres submitted via `PATCH /auth/profile`, ratings via `POST /tracking/` per movie — both fire on OnboardingCompleteView "Let's go" tap.
- **Models**: Codable structs matching backend Pydantic schemas (snake_case → camelCase via CodingKeys). `FeedRequest` / `GroupFeedRequest` for POST body with exclude list.
- **Infinite scroll**: Exclude-based pagination — frontend tracks seen `tmdb_id`s in a `Set<Int>`, sends them as `exclude` param (browse) or POST body (FYP/groups). Backend excludes those IDs from the candidate pool before sampling. Load-more triggers at last 4 items via `.onAppear` (grid) or `ReelsFeedView.onLoadMore` (reels).
- **Screenshot mode**: `APIConfig.screenshotMode` bool + `.posterBlur()` ViewModifier. When `true`, blurs all TMDB images (posters, backdrops, cast) with `blur(radius: 20)` for App Store screenshots. No-op when `false`.
- **Reels feed**: Instagram Reels-style vertical paging (`ScrollView` + `.scrollTargetBehavior(.paging)` + `GeometryReader` for card height). `ReelMovie` normalizes all movie response types. `ReelsFeedView` prefetches `MovieResponse` details for current card ± 3 neighbors via `TaskGroup`. Cards show pulsing skeleton placeholders until detail loads. Reel cards are self-contained detail views (no tap-to-navigate) — show title + match badge, trailer, genre pills, tagline, expandable overview, and compact cast section. Horizontal swipe with spring snap-back + haptic feedback: left → watchlist (optimistic), right → inline rating overlay. YouTube trailers autoplay via IFrame Player API (`youtube-nocookie.com` host/origin, `controls: 0`, invisible until playing via CSS opacity transition). Grid/reels toggle via `ViewMode` enum on Home + Group views. Shared pinned header on both modes (no layout shift on toggle). `ReelCardView` split into extensions: `ReelCardSections.swift` (view sections) + `ReelCardActions.swift` (gestures).
- **Match badge**: AI purple gradient pill (`AppTheme.aiPurple` / `AppTheme.aiGradient`) shown inline next to title in reels + detail view. Grid cards use original black style.
- **Tutorial overlay**: 3-step walkthrough (`ScrollHintOverlay`) on first launch — covers vertical scroll, swipe-left, swipe-right. Persisted via `UserDefaults("hasSeenReelsTutorial")`, never shown again after dismiss.

## Project Structure

```
blnd_ios/blnd_ios/
├── App/
│   └── blndApp.swift              BlndApp entry point, injects AuthState + OnboardingState into environment
├── Config/
│   ├── APIConfig.swift            base URL constant (change to local IP for device testing)
│   ├── SupabaseConfig.swift       Supabase project URL + storage bucket name
│   └── KeychainManager.swift      save/read/delete tokens via Security framework
├── Models/
│   ├── AuthModels.swift           SignupRequest, LoginRequest, UpdateProfileRequest (username, displayName, tasteBio, favoriteGenres, avatarUrl), LoginResponse, UserResponse, UserSearchResult, UserSearchResponse
│   ├── MovieModels.swift          FeedRequest, Genre, CastMember, MovieResponse (incl matchScore, trailerUrl), MovieSearchResult, RecommendedMovieResponse, RecommendationsResponse
│   ├── ReelMovie.swift            Normalized movie struct for reels feed — factory inits from RecommendedMovieResponse, MovieResponse, GroupRecMovieResponse, WatchlistMovieResponse
│   ├── TrackingModels.swift       TrackMovieRequest, WatchedMovieResponse, WatchlistMovieResponse, FriendWatchedResponse, etc.
│   ├── FriendModels.swift         SendFriendRequestRequest, FriendResponse (incl avatarUrl), FriendRequestResponse, FriendListResponse, PendingRequestsResponse
│   └── GroupModels.swift          GroupFeedRequest, CreateGroupRequest, AddMemberRequest, UpdateGroupRequest, GroupResponse, GroupDetailResponse, GroupMemberResponse, GroupRecMovieResponse, etc.
├── Networking/
│   ├── APIClient.swift            singleton, request(), requestVoid(), Bearer token, notFound error
│   ├── AuthAPI.swift              signup(), login(), me(), updateProfile(username/displayName/tasteBio/favoriteGenres/avatarUrl), searchUsers()
│   ├── AvatarUploader.swift       uploads UIImage JPEG to Supabase Storage, returns public URL with cache-bust
│   ├── MoviesAPI.swift            discover(genres:exclude:), search(query:page:), trending(exclude:), topRated(exclude:), getMovie() + RecommendationsAPI (getFeed/getRecommendations/refresh/hide/unhide/getHidden)
│   ├── TrackingAPI.swift          trackMovie, getWatchHistory, getWatchedMovie, deleteWatchedMovie, addToWatchlist, removeFromWatchlist, getWatchlist, getWatchlistStatus, friendsWhoWatched
│   ├── FriendsAPI.swift           listFriends, sendRequest, getPendingRequests, acceptRequest, rejectRequest, removeFriend
│   └── GroupsAPI.swift            listGroups, createGroup, getGroup, updateGroup, deleteGroup, addMember, kickMember, leaveGroup, getRecommendations, getFeed(exclude:), getWatchlist, addToWatchlist, removeFromWatchlist
├── State/
│   ├── AuthState.swift            @Observable, signup/login/logout/fetchCurrentUser, bootstraps UserActionCache
│   ├── TabState.swift             @Observable, selectedTab, pendingRequestCount, homeRefreshTrigger
│   ├── OnboardingState.swift      caches name/username/email/password/genres/ratings (tmdbId→liked) during onboarding
│   └── UserActionCache.swift      singleton in-memory cache of watched ratings + watchlisted IDs, bootstrapped on login
├── Theme/
│   └── AppTheme.swift             colors (incl aiPurple, aiGradient), corner radii, spacing, gradients, posterBlur()
├── Views/
│   ├── ContentView.swift          gates on authState.isAuthenticated
│   ├── MainTabView.swift          4-tab layout (Home, Friends, Blends, Profile), injects TabState
│   ├── Auth/
│   │   ├── WelcomeView.swift      landing page with login/signup buttons
│   │   ├── OnboardingView.swift   NavigationStack wrapper with AuthRoute enum
│   │   ├── SignUpView.swift       step 3: collects name/username/email/password, calls signup API, email validation
│   │   ├── LoginView.swift        wired to authState.login(), also defines BackButton component
│   │   ├── PickGenresView.swift   genre selection cached in OnboardingState
│   │   ├── RateMoviesView.swift   fetches genre-based movies from discover API, swipe cards with posters
│   │   └── OnboardingCompleteView.swift  submits genres + ratings to API, then sets authenticated
│   ├── Home/
│   │   ├── HomeView.swift         FYP + Discover tabs, reels/grid toggle, navigation state
│   │   ├── HomeViewReels.swift    Reels mode header + feed for HomeView
│   │   ├── HomeViewGrid.swift     Grid mode layout for HomeView
│   │   ├── HomeViewData.swift     Data loading (recommendations, refresh, error handling)
│   │   ├── SearchResultsView.swift  fullscreen SearchView with live debounced search (350ms), auto-focus
│   │   ├── MovieDetailView.swift  fetches by tmdbId, match score badge, tappable trailer, watched/unwatch/watchlist picker, cast, friends who watched
│   │   ├── RateMovieSheet.swift   half-sheet, half-star rating input, wired to POST /tracking/
│   │   ├── FriendsWhoWatchedSection.swift  shows friends who watched a movie with avatars + ratings
│   │   ├── DiscoverSectionView.swift  discover section, supports reels + grid modes
│   │   └── DiscoverSectionData.swift  data loading for discover (pagination, filter actions)
│   ├── Friends/
│   │   ├── FriendsListView.swift  Friends/Requests tabs, accept/reject, pull-to-refresh, avatar support
│   │   ├── FriendProfileView.swift  friend data with avatar, remove friend with confirmation
│   │   ├── AddFriendView.swift    Instagram-style live user search, send request inline, avatars
│   │   └── ActivityFeedView.swift  Unified notification inbox (GET /notifications/inbox)
│   ├── Groups/
│   │   ├── GroupsListView.swift   real data, member count + avatar stack, pull-to-refresh
│   │   ├── GroupDetailView.swift  blend picks, group watchlist, reels/grid toggle, members
│   │   ├── GroupDetailReels.swift reels mode header + feed for GroupDetailView
│   │   ├── GroupDetailGrid.swift  grid mode layout for GroupDetailView
│   │   ├── GroupDetailActions.swift  data loading (loadAll, rename)
│   │   ├── CreateGroupView.swift  creates group via API, loading/error states
│   │   ├── GroupMembersSheet.swift  member list with kick/leave actions
│   │   └── AddGroupMemberSheet.swift  friends picker to add members, avatars
│   ├── Profile/
│   │   ├── ProfileView.swift      real user data + avatar, watched/watchlist poster grids, bell icon (notifications), tappable friends/groups stats
│   │   ├── SettingsView.swift     navigates to Account/Notifications/Privacy/About with icons, logout
│   │   ├── AccountSettingsView.swift  edit display name, username, avatar upload (PhotosPicker) / remove via Supabase
│   │   ├── NotificationsSettingsView.swift  Wired to GET/PATCH /notifications/preferences (4 toggles)
│   │   ├── PrivacySettingsView.swift  Apple-style green toggles (coming soon placeholder)
│   │   └── AboutSettingsView.swift  app version, branding
│   └── Shared/
│       ├── AppButton.swift        isLoading prop with spinner
│       ├── MovieCard.swift        AsyncImage poster support via posterPath prop
│       ├── SearchBar.swift        reusable search bar component
│       ├── AvatarView.swift       accepts optional url param, AsyncImage with gradient circle fallback
│       ├── CastSectionView.swift  horizontal cast list with avatars (uses array index for ForEach id)
│       ├── GenrePill.swift        genre tag capsule
│       ├── TasteMatchBadge.swift  match % badge
│       ├── StarRatingInput.swift  interactive half-star rating + StarRatingDisplay read-only
│       ├── WatchlistPickerSheet.swift  Spotify-style add to personal/group watchlists
│       ├── SwipeBackGesture.swift  edge-swipe dismiss modifier for views with hidden back button
│       ├── OnboardingProgressBar.swift  step indicator for onboarding flow
│       ├── ViewMode.swift         enum: .reels / .grid
│       ├── ReelsFeedView.swift    Core vertical paging ScrollView with prefetch cache + toast
│       ├── ReelCardView.swift     Full-screen reel card: properties, body, state (slim — sections in extensions)
│       ├── ReelCardSections.swift View sections extension: title, media, details (tagline, expandable overview, cast, genres), skeleton, swipe indicators, rating overlay
│       ├── ReelCardActions.swift  Gesture handling + watchlist/rating actions for ReelCardView
│       ├── ReelTrailerView.swift  WKWebView YouTube IFrame Player API with autoplay, mute, controls
│       ├── ReelRatingOverlay.swift  Inline star rating overlay on reel cards
│       ├── ReelSwipeIndicator.swift  Visual indicator during horizontal swipe (bookmark/star icons)
│       └── ReelToast.swift        Brief auto-dismissing toast for swipe actions
```

## Conventions

- Use `@Observable` (not `ObservableObject`)
- Use `async/await` (not Combine)
- Use `AsyncImage` for remote images
- Use Security framework for Keychain (not third-party)
- All API calls go through `APIClient.shared`
- Models use `CodingKeys` to map backend `snake_case` to Swift `camelCase`
- `AvatarView(url:size:overlap:)` for all avatar displays — pass `avatarUrl` from models

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

## Supabase

- Project URL: `https://wtnbecnjsougjjcplhqf.supabase.co`
- Storage bucket: `avatars` (public read, authenticated write)
- Avatar path: `avatars/{user_id}/avatar.jpg`
- Auth: uses same JWT from backend (Bearer token) for storage uploads
- Cache busting: append `?v=<timestamp>` to public URL on upload so AsyncImage doesn't serve stale cache

## Analytics (PostHog)

- **SDK**: `posthog-ios` v3.49+, initialized in `blndApp.swift`
- **API Key**: configured in `blndApp.init()`
- **Auto-captured**: screen views, app lifecycle (open/close/background)
- **User identification**: `identify(userId)` on login, Apple Sign In, session restore. `reset()` on logout.
- **Event naming**: `verb_noun`, snake_case. Add `source` property when same action can happen from multiple places.
- **Tracked events**:
  - `movie_rated` — properties: `tmdb_id`, `rating`, `source` (reels/detail)
  - `watchlist_added` — properties: `tmdb_id`, `source` (reels)
  - `movie_hidden` — properties: `tmdb_id`
  - `trailer_played` — properties: `video_id`
  - `tab_switched` — properties: `tab` (For You/Discover)
  - `onboarding_completed` — no properties
  - `friend_request_sent` — no properties
  - `group_created` — no properties
- **Files with PostHog imports**: blndApp.swift, AuthState.swift, ReelCardActions.swift, ReelRatingOverlay.swift, ReelTrailerView.swift, HomeView.swift, FindFriendsView.swift, AddFriendView.swift, FriendProfileView.swift, CreateGroupView.swift, RateMovieSheet.swift

## Design

- **Theme**: Dark monochrome, Cal.com/X aesthetic
- **Colors**: Black bg (#000), cards (#1A1A1A), borders (#2A2A2A), text (#FFF / #999 / #666)
- **No accent color** — movie posters provide all color
- **Typography-driven**: Big bold titles, whitespace, thin dividers
- **4 tabs**: Home (with search), Friends, Blends (groups), Profile
- **Settings toggles**: Apple default style with green tint

## Screens (20+ total)

- **Onboarding (4)**: Pick Genres → Rate Movies (swipe cards) → Create Account (signup API call) → You're In
- **Home (3)**: Home Feed (reels default + grid toggle), Search Results, Movie Detail
- **Friends (3)**: Friends List, Friend Profile, Add Friend
- **Groups (3)**: Groups List, Group Detail (reels default + grid toggle), Create Group
- **Profile (6)**: Profile, Settings, Account (edit name/username/avatar), Notifications, Privacy, About
- **Shared (2)**: Rate Movie bottom sheet, Reels feed (shared across Home FYP, Discover, Group Blends/Watchlist)

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
24. AuthAPI: added updateProfile() for PATCH /auth/profile (username, display_name, taste_bio, favorite_genres, avatar_url)
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
35. Onboarding signup: username field added to SignUpView + OnboardingState, backend validates uniqueness + format (3-30 chars, a-z0-9._)
36. Genre-based movie discovery: backend GET /movies/discover?genres= (TMDB discover API, no auth), RateMoviesView fetches top 10 movies from selected genres with real poster images
37. Onboarding ratings: liked → 4.0, disliked → 2.0 (haven't seen = skip)
38. Swipe-back gesture: SwipeBackGestureModifier re-enables edge swipe on views with hidden back button (MovieDetail, FriendProfile, Settings, GroupDetail)
39. Tab navigation from profile: TabState @Observable, ProfileView friends/groups stats tap switches tab
40. Settings sub-pages: SettingsView with icons navigates to Account, Notifications, Privacy, About
41. Account settings: edit display name + username via PATCH /auth/profile, avatar upload/remove via Supabase Storage
42. Avatar upload pipeline: PhotosPicker → UIImage → JPEG compress → Supabase Storage POST (x-upsert) → public URL with cache-bust → PATCH /auth/profile
43. RateMovieSheet: removed note/review field, ratings only
44. AvatarView: accepts optional url param, shows actual avatar via AsyncImage everywhere (ProfileView, FriendProfileView, FriendsListView, AddFriendView, FriendsWhoWatchedSection, AddGroupMemberSheet)
45. CastSectionView: fixed ForEach nil ID crash by using array index
46. Settings toggle style: Apple default with green tint (.tint(.green))
47. Re-rate movie: UpdateTrackingRequest model, TrackingAPI.updateRating() via PATCH /tracking/{tmdb_id}, RateMovieSheet pre-fills existing rating and uses PATCH for updates vs POST for new, button shows "Update Rating"

48. Reels-style movie feed: ReelMovie model, ReelsFeedView (vertical paging + prefetch), ReelCardView (skeleton → trailer + info), horizontal swipe gestures (watchlist/rate), ReelTrailerView (YouTube autoplay muted with controls), ReelRatingOverlay, ReelSwipeIndicator, ReelToast, ViewMode toggle (reels/grid) on Home + GroupDetail, HomeView split into extensions (Reels/Grid/Data), GroupDetailView split into extensions (Reels/Grid), DiscoverSectionView supports both modes
49. MovieDetailView: "more" button for long descriptions (replaced unreliable ViewThatFits with simple always-visible "more" button)
50. Reels inline detail: removed tap-to-navigate in reels mode (grid mode unaffected), expanded reel cards with tagline, expandable overview ("more" button), compact cast section (36x36 avatars, max 8). ReelCardView split into extensions (ReelCardSections.swift for view sections). Removed onNavigateToDetail from entire chain (8 files).
51. YouTube autoplay fix: replaced plain iframe embed with YouTube IFrame Player API in ReelTrailerView — uses onReady callback with explicit mute() + playVideo() for reliable autoplay on iOS WKWebView.
52. Screenshot mode: `APIConfig.screenshotMode` flag + `.posterBlur()` ViewModifier blurs all TMDB images (posters, backdrops, cast photos) across 7 files when enabled. For taking App Store screenshots without copyrighted movie art. No-op when false.
53. Infinite scroll for FYP: `RecommendationsAPI.getFeed(exclude:limit:)` POST endpoint, `HomeView` tracks `seenFYPIds`, `loadMoreFYP()` sends exclude list for fresh batches. Default batch size: 20. Triggers at last 4 items in both reels and grid modes. Backend rebuilds taste profile every 5 actions (rate/hide/watchlist) in background.
54. Infinite scroll for Discover: replace page-based pagination with exclude-based (`seenIds` set). `MoviesAPI.trending(exclude:)`, `.topRated(exclude:)`, `.discover(genres:exclude:)` — backend softmax-samples 20 from 100 TMDB movies per call, exclude ensures no duplicates across batches.
55. Infinite scroll for Groups: `GroupsAPI.getFeed(groupId:exclude:limit:)` POST endpoint, `GroupDetailView` tracks `seenRecIds`, `loadMoreRecs()` in both reels and grid modes.
56. No re-fetch on navigate back: `loadForYou()` guards on `recommendations.isEmpty`, `loadMovies()` guards on `movies.isEmpty`, `loadAll()` guards on `group == nil`. Rating a movie does not trigger taste rebuild or page refresh.
57. Sticky search in grid mode: `ScrollOffsetKey` preference tracks scroll offset. When user scrolls up while past the header (`offset < -100`), a compact sticky search bar slides in from top. Hides on scroll-down or when back at top. Reels mode has fixed header (always visible).
58. Shared pinned headers: Home + Group Detail views use a single header component (title bar + view mode toggle + tab picker) pinned above content. Both reels and grid modes render below the same header — no layout shift on toggle.
59. Match badge: AI purple gradient pill inline next to movie title in reels + detail view. `AppTheme.aiPurple` (#8B7BB5) + `AppTheme.aiGradient`. Grid cards keep original black badge.
60. Friend request badge: `TabState.pendingRequestCount` fetched on launch + tab switch. `.badge()` on Friends tab. Cleared after accept/reject.
61. UserActionCache: singleton in-memory cache bootstrapped on login. Tracks watched ratings + watchlisted IDs. Updated inline on all rate/watchlist/unwatch actions. Eliminates redundant status API calls.
62. Tutorial overlay: 3-step walkthrough (scroll, swipe-left watchlist, swipe-right rate) with progress dots + Next/Skip/Got it. Persisted via UserDefaults, shown once per install.
63. Smoother swipe gestures: spring snap-back animation, haptic on threshold cross, optimistic watchlist toast. `@State swipeOffset` replaces `@GestureState` for animated reset.
64. YouTube trailer optimizations: `controls: 1` (native YouTube controls for seeking/progress), CSS opacity mask (invisible until playing state 1), no artificial delay, `WKNavigationDelegate` for YouTube link handling.
65. Swift 6 concurrency fixes: `Sendable` on KeychainManager/LoginResponse/RefreshTokenRequest, `@unchecked Sendable` on APIClient, `@MainActor` on TokenRefresher task.
66. Cleaner Letterboxd import page: left-aligned header, step titles + descriptions, privacy note, split into extension file.
67. Cleaner rating overlay: minimal 3-element design (title, stars, capsule button), appear/dismiss animations.
68. Pulsing skeleton: `SkeletonRect` breathes between full and 40% opacity on 1s loop.
69. WatchlistPickerSheet: uses `GET /watchlist/status/{tmdb_id}` (2 API calls instead of 7+).
70. Consistent avatars: cast + friends who watched both use 36x36 avatars + 9pt text across detail view and reels. Friends who watched section added to reel cards (fetched lazily per card, cached in UserActionCache).
71. Discover filter header: shared `filterHeader` component (chips + genre picker + divider) pinned above both reels and grid modes — no layout shift or divider flicker on toggle.
72. Reel card overview: smart "more"/"less" toggle — measures full vs truncated height via GeometryReader preferences, only shows button when text is actually truncated. Cast + friends hidden when expanded to save space.
73. Friends navigation: tapping a friend avatar in "Watched by" (both detail view and reels) navigates to `FriendProfileView` via `NavigationLink`. `FriendWatchedResponse.asFriendResponse` adapter.
74. CachedAsyncImage: drop-in AsyncImage replacement with URLCache (50MB memory + 200MB disk). Replaced all 10 AsyncImage usages. Prevents re-downloading posters/avatars/backdrops on scroll/navigation.
75. ReelMovie array caching: pre-computed `fypReelMovies`, `groupReelMovies`, `discoverReelMovies` in `@State`. Eliminates `.map { ReelMovie(from:) }` in view body — fixes UI freeze on swipe actions.
76. UserActionCache expanded: also caches groups list, friends + pending requests, movie detail responses (global prefetch), friends-who-watched per movie, pending detail IDs (deduplicates in-flight prefetches).
77. WatchlistPickerSheet: uses cached groups + personal watchlist status from UserActionCache. Only fetches group status from API. Opens near-instantly.
78. ProfileView: removed redundant `fetchCurrentUser()`, `loadCounts()` uses cached friends/groups.
79. TMDB rating on reel cards: `★ 4.3` in meta line from `fullDetail.voteAverage`.
80. YouTube link fix: navigation delegate intercepts all `youtube.com`/`youtu.be` URLs → opens in Safari.
81. Toast: moved from top to bottom of screen, duration reduced to 1.2s.
82. Dynamic overview height: `overviewMaxHeight` computed from card geometry (card height minus title, media, genres, tagline, cast, friends heights). Overview fills available space instead of hardcoded 80pt cap. "more" only shows when text still overflows. Expanded overview uses `.fixedSize(vertical: true)` so "less" button sits right below last line.
83. YouTube button fix: added `WKUIDelegate` + `createWebViewWith` to both `TrailerPlayer.Coordinator` (ReelTrailerView) and `YouTubeWebView.Coordinator` (YouTubePlayerView). YouTube logo `target="_blank"` / `window.open()` now opens in Safari/YouTube app instead of silently failing.
84. Reel media gradient: trailer placeholder uses `AppTheme.posterGradient` (blue-to-red) instead of flat `AppTheme.card`, matching MovieDetailView's `heroPlaceholder` style.
85. Reels paging fix: replaced `.scrollTargetBehavior(.paging)` with `.viewAligned(limitBehavior: .alwaysByOne)` to eliminate sub-pixel drift that skipped cards after ~10 swipes. Load-more moved from `onAppear` to `onChange(of: currentId)` to prevent array mutation during active scroll.
86. Trailer tab isolation: `ReelsFeedView` accepts `isTabVisible` param. Home passes `tabState.selectedTab == 0`, Groups passes `tabState.selectedTab == 2`. When a tab is inactive, its reel cards become inactive → trailers stop and resources are freed for the active tab.
87. Group rename: any member can tap pencil icon on group name to rename. Input sanitized (trim whitespace, reject empty, 50-char max). Optimistic UI update with rollback on API failure. `GroupDetailResponse.name` changed to `var`.
88. Watchlist reels enrichment: backend `_watchlist_to_response` now returns full movie details (year, overview, genres, runtime, vote_average, director, cast, tagline, backdrop_path). iOS `WatchlistMovieResponse` + `ReelMovie(from:)` updated to map all fields. Group/personal watchlist reels now show full cards.
89. Screenshot blur reduced from 20 → 5 for lighter obscuring of poster art.
90. Refresh trailer fix: `ReelsFeedView.onChange(of: movies)` now resets `currentId` when the current movie is no longer in the list (e.g., after FYP refresh), so the first card becomes active and its trailer autoplays.
91. Tutorial overlay: animated gesture demos replacing static SF Symbol icons. `ScrollDemo` (cards float up with chevron), `SwipeLeftDemo` (card slides left, bookmark fades in), `SwipeRightDemo` (card slides right, star fades in). All loop with `repeatForever(autoreverses: true)`.
92. User search by display name: backend `search_users` now matches `username ILIKE 'q%'` OR `display_name ILIKE '%q%'`. No iOS changes needed.
93. Onboarding swipe card poster fix: added `.id(currentIndex)` to front `SwipeCard` in `RateMoviesView` so `CachedAsyncImage` recreates on advance instead of showing stale poster from previous card.

94. Find Friends from Contacts: onboarding step 5/5 (`FindFriendsView`), requests contacts permission, uploads phone numbers via `FriendsAPI.uploadContacts()`, shows sync count. Skip option. Auth finalization moved here from OnboardingCompleteView.
95. Change Password: `ChangePasswordView` in Account Settings, validates 8+ chars + 1 uppercase + confirm match, calls `AuthAPI.changePassword()`. NavigationLink from AccountSettingsView.
96. Tutorial overlay per-user: `@AppStorage("hasSeenReelsTutorial")` / `hasSeenBlendsTutorial` — one flag per device (not per-user). Tutorial only shows when feed is loaded (`!isLoadingFYP, !fypReelMovies.isEmpty`).
97. For You tutorial animation: replaced scroll-up demo with `ForYouTasteDemo` (film icons converging into sparkle) to match blends tutorial style.
98. Fix loadFriends() race condition: task cancellation before new fetch, removed duplicate call from `.onAppear`.
99. Cancel stacked toast tasks in Home, Groups, and ReelsFeedView.
100. Memoize `overviewMaxHeight`: computed once on cardSize change via `.onChange`, stored in `@State`.
101. Reduce FYP/group feed batch size from 50 to 20 for faster taste rebuild responsiveness.
102. Profile avatar fix: `fetchCurrentUser()` now called after `login()` and `loginWithApple()` so `currentUser` (including avatarUrl) is populated before ProfileView renders.
103. Search result profiles: `userRow()` and `suggestionRow()` in AddFriendView wrapped in NavigationLink → FriendProfileView. Non-friends see gated watched movies.
104. Forgot password: `ForgotPasswordView` + `.forgotPassword` AuthRoute, linked from LoginView.
105. Phone number in signup: optional phone field in SignUpView, passed through OnboardingState → AuthState.signup().
106. PrivacyInfo.xcprivacy: privacy manifest declaring collected data (email, phone, contacts, user ID, usage data) and UserDefaults API usage.
107. Friendship status on search results: `addButton` shows "Friends" / "Pending" / "Add" based on `friendshipStatus` from backend.

108. Notification inbox: bell icon on Profile page opens ActivityFeedView (GET /notifications/inbox). Shows all events (friend requests, accepts, blend invites, watchlist adds, friend ratings, digests) with avatar, body, time ago, unread dot. Marks all read on open. Unread count loaded on profile appear, refreshed on return. NotificationAPI: getInbox(), markInboxRead(). InboxItem + InboxResponse models.
109. Notification settings wired: NotificationsSettingsView loads from GET /notifications/preferences, saves via PATCH. 4 toggles (Friend Requests, Blend Invites, Recommendations, Friend Activity) with subtitles. Reverts on API failure. System settings link.
110. Badge reset on foreground: ContentView watches scenePhase, clears iOS badge + calls POST /notifications/badge/reset when app becomes active.
111. Push registration: AppDelegate registers APNs token → POST /notifications/device. Deep link routing for friend_request, friend_accepted, group_invite, group_watchlist, friend_activity notifications.
112. "Group" → "Blend" rename in notification settings subtitle.

## Next Steps

113. Letterboxd import (POST /import/letterboxd — file upload in settings)
109. Add avatar_url to backend GroupMemberResponse so group member avatars show
110. Profile edit UI (taste bio — backend already wired)
111. Polish: empty states, error handling

### BLND+ (Premium) — In Progress

Backend is fully wired (RevenueCat webhook, admin grant, tier-based group cap, subscription fields on profile). iOS partially done:

**Branding:** "blnd+" (lowercase, plus sign). Display name in RevenueCat entitlement = "blnd+". App Store Connect subscription localization can optionally be updated to match but isn't required — Apple uses its own display name on receipts/management screens.

**Done:**
- RevenueCat SDK added (5.68.0) + configured in blndApp.swift init()
- Purchases.shared.logIn/logOut synced on all auth paths (AuthState)
- UserResponse extended with subscriptionTier + subscriptionExpiresAt + isPremium computed
- AuthState.isPremium computed from currentUser
- BlndPlusBadge reusable view ("blnd" white + "+" silver-to-white gradient)
- PaywallView (custom): feature list, offering price, purchase button, restore purchases
- Settings: premium section (upgrade/active), restore purchases, manage subscription rows
- Profile: BlndPlusBadge shown under username when premium
- Gold angular gradient ring on AvatarView for premium users (AppTheme.premiumRingGradient)
- BlndPlusBadge + gold ring on FriendProfileView (public, visible without friendship)
- PublicProfileResponse includes subscriptionTier from backend
- AppTheme.premiumGradient (text) + premiumRingGradient (avatar ring) added
- Any group member can kick non-owners (removed owner-only restriction on kick button)

**TODO:**
- Create StoreKit Configuration file for local testing (Products.storekit with blnd_premium_monthly)
- Test full purchase flow on device with sandbox account
- Wire paywall trigger from Discover page ("Search with AI" button — gated, shows paywall for non-premium)
- Build semantic discover backend endpoint (POST /recommendations/semantic-discover — premium-gated)
- iOS: call semantic discover endpoint from AI search UI
- Submit app build with subscription to TestFlight (required for prod purchases)
- RevenueCat: entitlement `premium`, offering `default`, product `blnd_premium_monthly`, webhook active at /webhooks/revenuecat

## Linting

- Pre-commit hooks: swiftlint + swiftformat + codespell
- Config: `.swiftformat` at repo root (maxwidth 120, trailing commas, `before-first` wrapping)
- swiftlint: type_name (uppercase start), cyclomatic_complexity (max 10), line_length (max 120), type_body_length (max 300), identifier_name (min 3 chars)
- Use `case let .foo(bar)` not `case .foo(let bar)` (hoistPatternLet)
- Use `///` doc comments for API declarations, `//` for inline/property comments
- Use spaces around range operators (`200 ..< 300`)
- Number literals: 6+ digits need underscore grouping (e.g. `872_585`), 5 or fewer don't (e.g. `76341`)
- Computed properties: use multi-line bodies (swiftformat `wrapPropertyBodies` rule)
- Avoid multiline `if let` with brace on new line (swiftlint `opening_brace` conflicts); keep on single line when possible
- swiftformat `redundantProperty`: don't assign to a local variable then immediately return it — return the expression directly

## Last Updated

2026-04-19

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `python3 -c "from graphify.watch import _rebuild_code; from pathlib import Path; _rebuild_code(Path('.'))"` to keep the graph current
