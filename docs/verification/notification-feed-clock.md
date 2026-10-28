# Notification feed test: injected clock

Bug: `NotificationFeedTests/groupsTodayThisWeekAndEarlier` failed when run shortly after midnight
(observed ~1:40 AM CT) because the fixture rows are relative to `Date()` (70 min, 2 h, 5 h ago)
and crossed into yesterday.

Fix: tests use an injected `fixedNow` (2:40 PM today, local calendar). Product code unchanged.

| Criterion | Test | Result |
|---|---|---|
| Red: clock at 01:40 reproduces failure | NotificationFeedTests with `clock(hour: 1)` | FAILED (exit 65), as expected — PROVEN |
| Green: pinned clock passes regardless of wall time | NotificationFeedTests with `clock(hour: 14)` | PASSED (exit 0) — PROVEN |

Command: `xcodebuild test -scheme blnd_ios -destination 'id=<iPhone 17 Pro>' -only-testing:blnd_iosTests/NotificationFeedTests`
