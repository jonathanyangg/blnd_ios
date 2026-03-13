# Coding Conventions

**Analysis Date:** 2026-03-12

## Naming Patterns

**Files:**
- PascalCase for view structs: `MovieDetailView.swift`, `FriendsListView.swift`, `AppButton.swift`
- PascalCase for model structs: `AuthModels.swift`, `MovieModels.swift`, `GroupModels.swift`
- camelCase for enum/manager files: `APIClient.swift`, `KeychainManager.swift`, `AvatarUploader.swift`
- PascalCase for singletons/classes: `BlndApp` (app entry point)

**Structs & Classes:**
- PascalCase: `BlndApp`, `AuthState`, `APIClient`, `MovieCard`, `AvatarView`
- Enums: PascalCase, usually nested or grouped: `private enum HomeTab: String, CaseIterable`, `enum AuthAPI`

**Functions:**
- camelCase: `signup()`, `fetchMovie()`, `handleResponse()`, `parseDetail()`
- API functions as static methods on enums: `AuthAPI.signup()`, `MoviesAPI.trending()`, `TrackingAPI.trackMovie()`
- Private helper methods start with underscore conventionally, but more commonly just marked `private`: `private func handleResponse()`
- Computed properties use multi-line bodies per swiftformat rules: see `AppTheme.posterGradient(angle:)` returns `LinearGradient`

**Variables:**
- Instance properties: camelCase: `isLoading`, `selectedTab`, `recommendations`, `currentUser`
- Boolean flags: prefix with `is`, `show`, or `has`: `isLoading`, `showSearch`, `isWatched`, `hasError`
- Private instance state: `@State private var selectedTab: HomeTab = .forYou`
- Environment injection: `@Environment(AuthState.self) private var authState`

**Types:**
- Codable models: PascalCase struct names matching backend schemas with CodingKeys for snake_case conversion
  - Example: `displayName` in Swift → `"display_name"` in JSON via `enum CodingKeys: String, CodingKey`
- Error enums: `APIError`, `AvatarError` with `LocalizedError` conformance
- Status/mode enums: private nested enums in views: `private enum HomeTab: String, CaseIterable`

## Code Style

**Formatting:**
- Tool: `swiftformat`
- Max width: 120 characters (warning at 120, error at 150 per swiftlint)
- Indent: 4 spaces
- Collection/argument wrapping: `before-first` (opening bracket on same line, elements on next)
- Trailing commas: enabled in .swiftformat but disabled in swiftlint (swiftformat applies them, swiftlint doesn't enforce)
- Self: explicitly removed where not needed (`.self remove` in .swiftformat)
- Unused arguments in closures: stripped
- Range operators: spaces around (e.g., `200 ..< 300` not `200..<300`)
- Number literals: 6+ digits need underscore grouping (e.g., `872_585`); 5 or fewer don't (e.g., `76341`)

**Linting:**
- Tool: `swiftlint`
- Config: `.swiftlint.yml`
- Key rules enforced:
  - `type_name`: uppercase start (PascalCase)
  - `cyclomatic_complexity`: max 10
  - `line_length`: warning at 120, error at 150
  - `type_body_length`: warning at 300 lines, error at 500
  - `file_length`: warning at 400 lines, error at 600
  - `function_body_length`: warning at 50 lines, error at 80 lines
  - `identifier_name`: minimum 3 characters (allows `id`, `x`, `y` via configuration)
  - `hoistPatternLet`: use `case let .foo(bar)` not `case .foo(let bar)`

**Pattern Usage:**
- `case let .foo(bar)` in switch statements for associated values
- Guard statements for early returns: `guard let data = read(key: key) else { return nil }`
- If-let chains: keep on single line under 120 chars to satisfy both swiftformat + swiftlint:
  ```swift
  guard let http = response as? HTTPURLResponse,
        200 ..< 300 ~= http.statusCode
  else {
      throw AvatarError.uploadFailed
  }
  ```

## Import Organization

**Order:**
1. Framework imports (Foundation, SwiftUI, UIKit, Security)
2. Project-internal imports (@testable for tests)
3. No local path imports (not applicable in iOS/Swift)

**Observed patterns:**
- Views: `import SwiftUI` only
- Networking: `import Foundation` for JSON coding, `import UIKit` when handling images
- State: `import Foundation` for Foundation types
- Models: `import Foundation` for Codable
- No wildcard imports

**Path Aliases:**
- Not detected (no alias configuration in project)

## Error Handling

**Patterns:**
- Define domain-specific error enums that conform to `LocalizedError`:
  ```swift
  enum APIError: LocalizedError {
      case invalidURL
      case unauthorized
      case badRequest(String)
      case notFound
      case decodingError
      case networkError(Error)

      var errorDescription: String? {
          switch self {
          case .invalidURL: return "Invalid URL"
          case let .networkError(error): return error.localizedDescription
          }
      }
  }
  ```

- `AvatarError` enum in `AvatarUploader.swift` follows same pattern

- Try/catch in async functions: catch errors, extract localizedDescription for user display:
  ```swift
  do {
      currentUser = try await AuthAPI.me()
  } catch {
      if case APIError.unauthorized = error {
          logout()
      }
  }
  ```

- API response error mapping centralizes logic in `APIClient.mapError()` to handle FastAPI error shapes:
  - 400/409: `{"detail": "string"}`
  - 422: `{"detail": [{"msg": "string", ...}]}`
  - 429: rate limit
  - Private helper `parseDetail(from:)` tries both shapes

- Network/cancellation errors caught explicitly:
  ```swift
  } catch is CancellationError {
      throw CancellationError()
  } catch let urlError as URLError where urlError.code == .cancelled {
      throw CancellationError()
  } catch {
      throw APIError.networkError(error)
  }
  ```

- Loading/error UI states in views: `@State` for `isLoading`, `errorMessage`, then conditional rendering:
  ```swift
  if isLoading {
      ProgressView()
  } else if let error = errorMessage {
      VStack { Text(error); Button("Retry") { ... } }
  } else if let movie {
      movieContent(movie)
  }
  ```

## Logging

**Framework:** `print()` only — no structured logging library

**Patterns:**
- Tag prefixes for debugging: `[APIClient]`, `[AvatarUploader]`
- Example: `print("[APIClient] Decoding \(T.self) failed: \(error)")`
- Raw response dumps in error cases for diagnosis: `print("[APIClient] Raw response: \(raw.prefix(500))")`
- No logging in production code path (only for debugging/error context)

## Comments

**When to Comment:**
- Document public API signatures with doc comments (see below for format)
- Explain non-obvious backend behavior: "Pydantic 422 validation error shape" above `mapError()`
- TODO/FIXME only when blocking work (generally avoided, exceptions logged in CLAUDE.md Next Steps)
- Explain state transitions in state managers: `// Don't set isAuthenticated here — onboarding still needs to complete`

**JSDoc/TSDoc:**
- Use `///` for public API declarations:
  ```swift
  /// Uploads a UIImage to Supabase Storage and returns the public URL.
  static func upload(image: UIImage, userId: String) async throws -> String

  /// PATCH /auth/profile — update profile fields
  static func updateProfile(...) async throws -> UserResponse

  /// GET /movies/discover — top movies by genre (no auth required)
  static func discover(genres: [String], page: Int = 1) async throws -> MovieSearchResult
  ```

- Use `//` for inline comments explaining implementation:
  ```swift
  // Shape 1: {"detail": "Username already taken"}
  if let obj = try? decoder.decode([String: String].self, from: data), let detail = obj["detail"] {
      return detail
  }
  ```

- MARK comments for section organization (common in views):
  ```swift
  // MARK: - Header
  // MARK: - Tab Picker
  // MARK: - Content
  ```

## Function Design

**Size:** Max 50 lines warning, 80 lines error per swiftlint `function_body_length`

**Parameters:**
- Named parameters for clarity, especially in API functions:
  ```swift
  static func discover(genres: [String], page: Int = 1) async throws -> MovieSearchResult
  ```
- Optional parameters with defaults over overloads:
  ```swift
  func request<T: Decodable>(
      endpoint: String,
      method: String = "GET",
      body: (any Encodable)? = nil,
      authenticated: Bool = false
  ) async throws -> T
  ```

**Return Values:**
- Generic types for decoding: `request<T: Decodable>() -> T`
- Void functions for write-only operations: `requestVoid()` for DELETE/PATCH with no response body
- Error throwing: `throws` keyword for recoverable errors, returning specific `LocalizedError` subtypes
- Async: `async throws` for network operations

## Module Design

**Exports:**
- Structs/classes are public by default (no explicit `public` keyword)
- Private implementation details marked `private`: `private func performRequest()`, `private struct ValidationErrorDetail`
- Nested enums scoped as `private` in views: `private enum HomeTab: String, CaseIterable`

**Barrel Files:**
- Not used — each module (Networking, Models, State, Views, Theme) has individual files
- No `__init__.swift` or index re-exports

**File structure per module:**
- `APIClient.swift` — singleton
- Domain-specific enums per file: `AuthAPI.swift`, `MoviesAPI.swift`, `GroupsAPI.swift`
- Models grouped by domain: `AuthModels.swift`, `MovieModels.swift`, etc.
- State classes as `@Observable`: `AuthState.swift`, `TabState.swift`, `OnboardingState.swift`
- Views grouped by feature folder: `Views/Home/`, `Views/Friends/`, `Views/Groups/`, `Views/Profile/`, `Views/Shared/`

---

*Convention analysis: 2026-03-12*
