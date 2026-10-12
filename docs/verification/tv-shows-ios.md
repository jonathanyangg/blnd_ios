# TV show support (iOS v1)

## Scope

This PR prepares the iOS client for the default-off backend TV API without
changing the movie flow. It adds decoding for TV responses, preserves missing
`media_type` as `nil`, exposes a deterministic TV badge decision, and routes a
new TV search call to `/tv/search`. No movie search UI is switched over yet.

## Acceptance criteria

| Criterion | Evidence | Status |
|---|---|---|
| TV search response decodes `tmdb_id`, `title`, `year`, and `media_type` | `decodeTVSearchResponse` | PARTIALLY_PROVEN |
| Existing movie responses remain decodable without `media_type` | `decodeMovieResponseWithoutMediaType` | PARTIALLY_PROVEN |
| TV badge decision follows decoded `media_type` | `tvBadgeDecisionUsesMediaType` | PARTIALLY_PROVEN |
| Backend TV search integration with real API | Not testable until backend flag is enabled | NOT_PROVEN |
| Visible TV badge in SwiftUI | Deferred; no simulator/UI test yet | NOT_PROVEN |
