# Technology Stack

**Analysis Date:** 2026-03-12

## Languages

**Primary:**
- Swift 5.0 - All application and framework code

## Runtime

**Environment:**
- iOS 26.2+ (unusual deployment target, likely Xcode simulator/preview issue)
- SwiftUI 5+ (iOS 17 minimum per CLAUDE.md)

**Package Manager:**
- None - Zero third-party dependencies

## Frameworks

**Core UI:**
- SwiftUI - All view rendering and UI composition
- UIKit - Supporting framework for integration (PhotosUI, WebKit)

**Concurrency:**
- async/await - All networking and async operations
- Task - Background execution

**State Management:**
- @Observable (Swift 5.9+) - Application state (@Observable class pattern)
- @Environment - Dependency injection and state propagation

**Media & Storage:**
- PhotosUI - Photo picker for avatar upload (`AccountSettingsView` uses `PhotosPicker`)
- Security framework - Keychain access via `KeychainManager`

**System Integration:**
- Foundation - URLSession for HTTP requests, JSON encoding/decoding
- WebKit - URL/deeplink handling (`Link` components for trailers)

## Key Dependencies

**None - Zero external dependencies**

App relies entirely on native iOS frameworks and Swift standard library.

## Configuration

**Environment:**
- API base URL: `APIConfig.baseURL` — Currently set to `https://blnd-backend.onrender.com` (change to localhost for development via `APIConfig.swift`)
- Supabase project URL: `https://wtnbecnjsougjjcplhqf.supabase.co` (hardcoded in `SupabaseConfig.swift`)
- Storage bucket: `avatars`

**Build:**
- Xcode project: `blnd_ios.xcodeproj` (auto-discovers Swift files, no manual pbxproj references needed)
- Configuration files: `blnd_ios/Config/` directory
  - `APIConfig.swift`: Backend API endpoint configuration
  - `SupabaseConfig.swift`: Supabase project and storage bucket configuration
  - `KeychainManager.swift`: Secure token storage via Security framework

**Secrets Storage:**
- Keychain via Security framework (`KeychainManager` class) stores:
  - `accessToken` - JWT bearer token for API requests
  - `refreshToken` - Token refresh credential
  - `userId` - User identifier

## Platform Requirements

**Development:**
- Xcode 15+ (Swift 5.0 minimum)
- iOS Simulator or physical device running iOS 17+
- For device testing: Change `APIConfig.baseURL` to Mac's local IP, run backend with `--host 0.0.0.0`

**Production:**
- iOS 17+ deployment target
- HTTPS backend (currently deployed to `https://blnd-backend.onrender.com`)
- Supabase Storage access (public read, authenticated write to `avatars/` bucket)

## Networking Stack

**HTTP Client:**
- URLSession.shared - Direct URLSession usage in `APIClient` and specialized uploaders

**Request/Response Handling:**
- JSONEncoder/JSONDecoder - Codable-based serialization
- Custom error mapping - FastAPI Pydantic 422 validation error handling

**Authentication:**
- Bearer token (JWT) in Authorization header
- Token injected by `APIClient.request()` via Keychain lookup
- Same token used for Supabase Storage uploads in `AvatarUploader`

**Error Handling:**
- Custom `APIError` enum in `APIClient.swift`:
  - `.invalidURL` - URL construction failure
  - `.unauthorized` (401) - Authentication required
  - `.badRequest` (400-499) - Client error with detail message
  - `.notFound` (404) - Resource not found
  - `.rateLimited` (429) - Rate limit exceeded
  - `.serverError` (500+) - Server error with status code
  - `.decodingError` - Response parsing failure
  - `.networkError` - Network connectivity issues

## Image/Media Handling

**Remote Images:**
- AsyncImage - Native SwiftUI component for remote image loading with fallbacks

**Avatar Upload Pipeline:**
- PhotosPicker (UIKit PhotosUI) for selection
- UIImage JPEG compression (0.8 quality) in-app
- Direct multipart upload to Supabase Storage (POST with x-upsert header)
- Cache busting via timestamp query parameter (`?v=<unix_timestamp>`)

**Movie Posters:**
- Backend provides `posterPath` in `MovieResponse`
- Rendered via AsyncImage with gradient fallback

---

*Stack analysis: 2026-03-12*
