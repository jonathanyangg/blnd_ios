# Testing Patterns

**Analysis Date:** 2026-03-12

## Test Framework

**Runner:**
- New Testing framework (Swift 5.9+) for unit tests
- XCTest for UI tests
- Config: No dedicated config file — tests auto-discovered by Xcode

**Assertion Library:**
- Testing framework macros: `@Test`, `#expect`
- XCTest assertions: `XCTAssertTrue()`, etc.

**Run Commands:**
```bash
xcodebuild test                              # Run all tests
xcodebuild test -scheme blnd_ios             # Run specific scheme
xcodebuild test -only-testing blnd_iosTests  # Run only unit tests
```

## Test File Organization

**Location:**
- Co-located in separate test targets: `blnd_iosTests/` and `blnd_iosUITests/`
- Not co-located with source files (separate target structure)
- Test target imports source via `@testable import blnd_ios`

**Naming:**
- Unit tests: `blnd_iosTests.swift` (should expand to individual test files per domain)
- UI tests: `blnd_iosUITests.swift` + `blnd_iosUITestsLaunchTests.swift`

**Structure:**
```
blnd_iosTests/
├── blnd_iosTests.swift          # Placeholder unit tests
blnd_iosUITests/
├── blnd_iosUITests.swift        # UI test cases
└── blnd_iosUITestsLaunchTests.swift
```

## Test Structure

**Suite Organization:**

```swift
// Unit tests (Testing framework)
@testable import blnd_ios
import Testing

struct BlndIOSTests {
    @Test func example() {}
}
```

```swift
// UI tests (XCTest)
import XCTest

final class BlndIOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {}

    @MainActor
    func testExample() {
        let app = XCUIApplication()
        app.launch()
    }
}
```

**Patterns:**
- Setup: `setUpWithError()` runs before each test
- Teardown: `tearDownWithError()` runs after each test
- Assertions: Currently placeholder; new tests should use `#expect` (Testing framework) or `XCTAssert*` (XCTest)
- UI tests marked `@MainActor` to ensure main thread execution

## Mocking

**Framework:** Not configured
- No mocking library detected (no Mockery, Nimble, Quick, etc.)
- Current codebase has no test mocks or stubs

**Patterns:**
- Not yet established; would typically mock `APIClient` for unit tests
- Proposed approach for networking tests:
  ```swift
  // Mock URLSession for APIClient tests
  class MockURLSession: URLSession {
      var mockResponse: (Data, HTTPURLResponse)?
      // Override data(for:) to return mock data
  }
  ```

**What to Mock:**
- Network calls (APIClient) — enable testing error paths without backend
- File operations (KeychainManager reads/writes)
- AsyncImage loads (would need custom image loading abstraction)

**What NOT to Mock:**
- View rendering (use UI tests instead)
- SwiftUI @State behavior (test views via UI tests)
- Simple value types (models, enums)

## Fixtures and Factories

**Test Data:**
- Not yet created; should establish in dedicated test utils

**Proposed pattern:**
```swift
// MockData.swift
struct MockMovieFactory {
    static func makeMovie(
        tmdbId: Int = 1,
        title: String = "Test Movie"
    ) -> MovieResponse {
        MovieResponse(tmdbId: tmdbId, title: title, ...)
    }
}
```

**Location:**
- Should live in test target: `blnd_iosTests/Mocks/` or `blnd_iosTests/Fixtures/`

## Coverage

**Requirements:** None enforced (no coverage threshold detected)

**View Coverage:**
```bash
xcodebuild test -scheme blnd_ios -codeCoverageTargets blnd_ios
# Open derived data for coverage.profdata analysis
```

## Test Types

**Unit Tests:**
- Target: `blnd_iosTests/blnd_iosTests.swift`
- Scope: API error handling, KeychainManager operations, model decoding
- Currently empty placeholder — needs expansion
- Approach: Test `APIClient.mapError()` with various HTTP status codes and response bodies

**Integration Tests:**
- Not yet implemented
- Should test: full auth flow (signup → login), API request/response cycle with real backend
- Proposed approach: conditional environment variable to point to test backend

**E2E Tests:**
- Framework: XCTest UI tests (`blnd_iosUITests/`)
- Structure: `BlndIOSUITests` class with `@MainActor` test methods
- Currently has placeholder `testExample()` and `testLaunchPerformance()`
- Scope: User flows (login → home feed → movie detail → rating)

## Common Patterns

**Async Testing:**
- Not yet established; Swift Testing framework supports async test methods
- Proposed pattern:
  ```swift
  @Test
  async func testSignup() {
      let state = AuthState()
      await state.signup(email: "test@example.com", ...)
      #expect(state.isAuthenticated)
  }
  ```

**Error Testing:**
- Proposed pattern for APIError:
  ```swift
  @Test
  func testMapErrorHandles401() {
      let client = APIClient()
      let error = client.mapError(status: 401, data: Data())
      #expect(error == .unauthorized)
  }
  ```

**View Testing:**
- UI tests launch app and interact: `XCUIApplication().launch()`
- Proposed pattern for SwiftUI views:
  ```swift
  @MainActor
  func testMovieDetailLoadsMovie() {
      let app = XCUIApplication()
      app.launch()
      let movieTitle = app.staticTexts["Dune"]
      #expect(movieTitle.exists)
  }
  ```

## Test Gaps

**Currently Untested:**
- All unit test areas (APIClient, KeychainManager, models, error handling)
- All view layers (HomeView, ProfileView, MovieDetailView, etc.)
- API integration (live backend calls)
- Avatar upload flow
- Onboarding state caching
- Watchlist interactions

**Critical Areas to Test:**
1. `APIClient.mapError()` — handles all FastAPI error shapes (400, 422, 429, 5xx)
2. `KeychainManager` — save/read/delete token lifecycle
3. `AuthState` — signup, login, logout, fetchCurrentUser, error handling
4. Model decoding — Codable snake_case → camelCase conversion
5. Rate limiting + auth failures (triggers logout)

---

*Testing analysis: 2026-03-12*
