# JSX-to-SwiftUI Converter Memory

## Project: blnd iOS

### File Structure (created 2026-03-02)
- 30 Swift files across `blnd/App/`, `blnd/Theme/`, `blnd/Views/`, `blnd/Extensions/`
- Entry: `blnd/App/blndApp.swift` -> `ContentView` -> auth gate -> `MainTabView` or `OnboardingView`
- Theme: `AppTheme` enum with static color/spacing/radius constants
- Color extension: `Color(hex: UInt)` initializer in `AppTheme.swift`

### Shared Components
- `AppButton` - primary/ghost/disabled styles
- `AppTextField` - styled text field with prompt text
- `MovieCard` - poster placeholder with gradient + optional title/year
- `SearchBar` / `SearchBarButton` - interactive and tappable variants
- `AvatarView` - gradient circle with overlap support
- `GenrePill` - active/inactive capsule, tappable or static
- `TasteMatchBadge` - circle with percentage
- `OnboardingProgressBar` - animated step indicator
- `BackButton` - reusable nav back button using `@Environment(\.dismiss)`
- `FlowLayout` - custom Layout for wrapping horizontal content (in PickGenresView.swift)

### Key Patterns
- All views use `AppTheme.background` as root background
- Navigation: `NavigationStack` at tab-level, `navigationDestination` for push
- Sheets: `.sheet()` with `.presentationBackground(AppTheme.background)`
- All previews use `#Preview` macro (iOS 17+)
- Dark mode enforced via `.preferredColorScheme(.dark)` on ContentView
- Tab bar: SF Symbols (house, person.2, circle.grid.2x2, person.circle), tinted white
