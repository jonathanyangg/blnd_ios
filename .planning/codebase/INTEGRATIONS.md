# External Integrations

**Analysis Date:** 2026-03-12

## APIs & External Services

**Backend (FastAPI):**
- Service: blnd backend (primary API)
- Endpoint: `https://blnd-backend.onrender.com` (production) or `http://localhost:8000` (development)
- What it's used for: Authentication, movie data, recommendations, friends, groups, tracking
- SDK/Client: Custom `APIClient` singleton in `Networking/APIClient.swift`
- Auth: Bearer JWT token stored in Keychain, injected as `Authorization: Bearer {token}` header

**The Movie Database (TMDB):**
- Service: TMDB API (accessed via backend proxy, not directly)
- What it's used for: Movie discovery, search, trending, details, cast, trailers
- SDK/Client: Backend handles TMDB integration; iOS app calls `/movies/*` endpoints
- Auth: Backend holds TMDB API key (not exposed to client)

**Supabase Storage:**
- Service: Supabase Storage (public bucket `avatars`)
- Endpoint: `https://wtnbecnjsougjjcplhqf.supabase.co/storage/v1/object/`
- What it's used for: User avatar upload and retrieval
- SDK/Client: Direct URLSession POST in `AvatarUploader.swift`
- Auth: Same JWT bearer token as backend API (Supabase trusts JWT from same issuer)
- Upload path: `avatars/{user_id}/avatar.jpg`
- Public URL format: `https://wtnbecnjsougjjcplhqf.supabase.co/storage/v1/object/public/avatars/{user_id}/avatar.jpg?v={timestamp}`

## Data Storage

**Databases:**
- Backend: Runs on PostgreSQL (via backend, not direct iOS access)
- Connection: iOS never connects directly; all data via REST API

**File Storage:**
- Supabase Storage (public `avatars` bucket)
- Upload mechanism: multipart/form-data POST with `x-upsert: true` header
- Image compression: UIImage JPEG 0.8 quality before upload
- Cache busting: Timestamp appended to public URL (`?v=<unix_timestamp>`)

**Caching:**
- AsyncImage framework cache (iOS native)
- No server-side caching headers configured (app relies on AsyncImage in-memory cache + disk cache)

**Local Persistence:**
- Keychain (via Security framework) — stores JWT tokens:
  - `accessToken` - API bearer token
  - `refreshToken` - Token refresh credential
  - `userId` - User identifier
- Keychain used via `KeychainManager` class in `Config/KeychainManager.swift`

## Authentication & Identity

**Auth Provider:**
- Custom JWT backend (FastAPI generates JWT)

**Implementation:**
- Email/password signup: `AuthAPI.signup()` → FastAPI POST `/auth/signup`
- Email/password login: `AuthAPI.login()` → FastAPI POST `/auth/login`
- Returns JWT + refresh token in `LoginResponse`
- Token stored in Keychain after auth
- Check current user: `AuthAPI.me()` → GET `/auth/me` (authenticated)

**Token Management:**
- Access token stored in Keychain as `accessToken`
- Refresh token stored as `refreshToken` (ready for refresh flow if implemented)
- Token passed to all authenticated requests via `APIClient.request(..., authenticated: true)`
- Token removed on logout via `KeychainManager.delete(key: "accessToken")`

**User Search:**
- `AuthAPI.searchUsers(query:)` → GET `/auth/users/search?q=` (live user search by username)
- Used in AddFriendView for finding users by username prefix

## Monitoring & Observability

**Error Tracking:**
- None detected - Console print logging only in `APIClient` (decoding errors)

**Logs:**
- Print debugging: `APIClient.request()` prints to console on decoding failures
- No structured logging or analytics

## CI/CD & Deployment

**Hosting:**
- Backend: Render (https://blnd-backend.onrender.com)
- iOS: App distributed via Xcode/TestFlight (not detected in codebase)

**CI Pipeline:**
- Pre-commit hooks: swiftlint, swiftformat, codespell (defined in CLAUDE.md)
- No GitHub Actions or CI detected in iOS app

## Environment Configuration

**Required env vars:**
- None in iOS app (all configuration hardcoded in source files)
- Backend credentials stored server-side

**Configuration files (not env-based):**
- `APIConfig.baseURL` - Hardcoded backend URL (change in source for dev/prod)
- `SupabaseConfig.projectURL` - Hardcoded Supabase project URL
- `SupabaseConfig.bucket` - Hardcoded storage bucket name (`avatars`)

**Secrets location:**
- Runtime: Keychain storage (iOS Security framework)
- Source: Not stored in repo (frontend-only secrets; backend keys live on Render)

## Webhooks & Callbacks

**Incoming:**
- None - iOS app is client-only, receives via polling/request-response

**Outgoing:**
- None detected

## API Endpoints

**Auth Endpoints** (in `AuthAPI.swift`):
- `POST /auth/signup` - Create account with email/password/username
- `POST /auth/login` - Login with email/password
- `GET /auth/me` - Fetch current user profile (authenticated)
- `GET /auth/users/search?q={query}` - Search users by username (authenticated)
- `PATCH /auth/profile` - Update profile: username, display_name, taste_bio, favorite_genres, avatar_url (authenticated)

**Movie Endpoints** (in `MoviesAPI.swift`):
- `GET /movies/discover?genres={genres}&page={page}` - Discover by genre
- `GET /movies/search?query={query}&page={page}` - Search movies
- `GET /movies/trending?page={page}` - Trending movies
- `GET /movies/top-rated?page={page}` - Top-rated movies
- `GET /movies/{tmdb_id}` - Movie detail with cast/ratings/trailer

**Recommendations** (in `MoviesAPI.swift`):
- `GET /recommendations/me?limit=50&offset=0` - Personalized recommendations
- `POST /recommendations/me/refresh?limit=50` - Refresh recommendations

**Tracking & Watchlist** (in `TrackingAPI.swift`):
- `POST /tracking/` - Track watched movie with rating
- `GET /tracking/?limit=20&offset=0` - Watch history
- `GET /tracking/{tmdb_id}` - Check if watched
- `PATCH /tracking/{tmdb_id}` - Update rating
- `DELETE /tracking/{tmdb_id}` - Remove watched movie
- `GET /tracking/{tmdb_id}/friends` - Friends who watched this movie
- `POST /watchlist/` - Add to personal watchlist
- `DELETE /watchlist/{tmdb_id}` - Remove from personal watchlist
- `GET /watchlist/?limit=20&offset=0` - Get personal watchlist

**Friends** (in `FriendsAPI.swift`):
- `GET /friends/` - List accepted friends
- `POST /friends/request` - Send friend request by username
- `GET /friends/requests` - Get pending requests (incoming + outgoing)
- `POST /friends/{id}/accept` - Accept request
- `POST /friends/{id}/reject` - Reject request
- `DELETE /friends/{id}` - Remove friend

**Groups** (in `GroupsAPI.swift`):
- `GET /groups/` - List user's groups
- `POST /groups/` - Create group
- `GET /groups/{id}` - Get group detail
- `PATCH /groups/{id}` - Update group name (owner only)
- `DELETE /groups/{id}` - Delete group (owner only)
- `POST /groups/{id}/members` - Add member by username
- `POST /groups/{id}/members/{uid}/kick` - Kick member (owner only)
- `POST /groups/{id}/leave` - Leave group
- `GET /groups/{id}/recommendations` - AI blend picks
- `GET /groups/{id}/watchlist?limit=20&offset=0` - Group watchlist
- `POST /groups/{id}/watchlist` - Add to group watchlist
- `DELETE /groups/{id}/watchlist/{tmdb_id}` - Remove from group watchlist

**Import** (in `ImportAPI.swift`):
- `POST /import/letterboxd` - Upload Letterboxd export ZIP (multipart/form-data)

## Rate Limiting

**Current:** None observed
- Backend returns 429 on rate limit
- App error handling in `APIClient.mapError()` → `.rateLimited` case
- No client-side rate limit enforcement

## Validation & Error Handling

**Validation:**
- Backend validates via FastAPI Pydantic
- App handles 422 validation errors: parses `detail` array with `msg` field per validation error

**Error Response Shapes:**
- 400/409: `{"detail": "string"}`
- 422: `{"detail": [{"msg": "string", ...}]}`
- 429: Plain text rate limit response

---

*Integration audit: 2026-03-12*
