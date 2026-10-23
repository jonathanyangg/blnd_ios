# Report / block on comments (App Store 1.2)

**Original task:** add a "Report" action on comments/UGC (Apple guideline 1.2); block-user already exists.

**What was done:** `CommentRowView` now shows, for other users' non-deleted comments, a visible "…" menu and a long-press context menu with **Report** (category picker: Spam / Harassment / Hate speech / Spoilers / Other) and **Block user** (confirm alert). Report uses the existing `POST /reports` (reported user + reason); the reason embeds `Comment #<id> [<category>]: <body excerpt>` (<=200 chars, backend limit) so moderators can locate the content. **No backend change needed.** Block uses `FriendsService.blockUser`. Accessibility ids: `comment.more`, `comment.report`, `comment.block`.

| Acceptance | Status | Evidence |
|---|---|---|
| Reason string includes comment id/category, <=200 chars | PROVEN | `CommentModerationTests` (4 tests) |
| Own/deleted/anonymous comments are not reportable | PROVEN | `cannotModerateOwnOrDeletedOrAnonymousComments` |
| Full unit suite green | PROVEN | `report-comments-test.log`: 123 passed, `** TEST SUCCEEDED **` |
| UI menu on device | NOT_PROVEN (no Maestro/screenshot; low-risk SwiftUI Menu) | — |
