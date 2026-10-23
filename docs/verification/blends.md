# Blends: "Find a movie for us", username invites, add-on-create

## Mini paper
**Original task:** improve the blend list and detail. Add a "Find a movie for us" pick, with Where to watch, Another pick and We watched it → rate. Replace the friends-only member picker with username search plus a share invite. Allow adding members on the create screen. Count the taps on the lowest-click two-friend path before and after.

**What was done**
- `GroupRecMovieResponse.reason: String?`: optional, so it decodes whether the field is present, `null` or missing. The local backend already sends `"reason": null`.
- `BlendPickDeck` / `BlendPickModel` (`blnd_ios/Models/BlendPick.swift`): the first recommendation is the pick. "Another pick" moves to the next item and wraps, with no extra request. The fetch is an injected closure; the default calls `GET /groups/{id}/recommendations`. Phases: loading, ready, empty, failed. The deprecated pick-tonight endpoints are not used.
- `BlendPickView` (sheet from the new `blend.findMovie` button on the blend detail): poster, title · year · match %, and a "Why this pick: …" line that is hidden when `reason` is nil. It reuses `StreamingSheet` for Where to watch and `RateMovieSheet` for logging (rating saved through the existing `TrackingAPI`). After saving it shows a "Logged · N★" confirmation (`blend.done`). The empty state asks members to rate a few movies; errors show `ErrorStateView` with retry.
- `BlendMemberPicker`: username search using the existing `AuthAPI.searchUsers`. Friends come first, then other users; members and self are excluded. Tapping a row adds that user. A `ShareLink` "Invite a friend" shares `Join my blnd blend — add me: @<myUsername>` (no URL). It is used by `AddGroupMemberSheet` and by `CreateGroupView`.
- `CreateGroupView`: the name is prefilled with "Movie night", and members are picked on the same screen. One Create tap creates the blend and adds everyone. If an add fails, a retry re-adds only the failed members and never creates a second blend. After creating, the list opens the new blend directly.
- Blend list: a "Create a Blend" CTA, a one-line empty state, "1 member"/"N members", and avatars with initials when `member_names` is present. The local backend does not send `member_names` on `GET /groups/`, so the gradient avatars stay. **Shared-taste summary: omitted**, because no list endpoint returns match data.
- Accessibility ids added for automation: `rating.star.N` (StarRatingInput), `rate.save` (RateMovieSheet), `streaming.close` (StreamingSheet), `blends.members.search`, `blends.member.<username>`, `blends.invite.share`, `blend.findMovie`, `blend.pick.title`, `blend.pick.reason`, `blend.whereToWatch`, `blend.watched`, `blend.anotherPick`, `blend.done`. `blends.name` moved from the Create button, where it was misplaced, to the name field.
- Maestro `04_create_blend` updated: Create now opens the blend instead of the "Add Member" step, so the flow erases the default name, types its own, asserts `blend.findMovie`, swipes back and asserts the row.

## Tap count: lowest-click path for two friends who just onboarded
A creates a blend with B → Find a movie → Where to watch → We watched it → rate. Taps are counted from A's Home tab; typing a username or name counts as text entry, not a tap.

| Step | BEFORE (dev) | AFTER |
|---|---|---|
| Become friends (dev picker is friends-only) | A: Profile, Friends, Add friend, search field, *type B*, Add (5) · **B: Profile, Friends, Accept (3)** | not needed (0) |
| Create blend + add B | Blends, New, name field, *type name*, Create, Add B, Done (6) | Blends, Create a Blend, search field, *type B*, tap B, Create (5) |
| Open blend | tap row (1) | auto-opened (0) |
| Get a pick | no single-pick UI; use the first reel card (0) | Find a movie for us (1) |
| Where to watch + close | Watch now, close (2) | Where to watch, close (2) |
| We watched it → rate → save | Watched with, star, Save (3) | We watched it, star, Save (3) |
| **Total taps** | **A 17 + B 3 = 20**, 2 text entries, both users must act | **A 11, B 0**, 1 text entry |

The AFTER count is exactly the `tapOn` steps of Maestro flow 08, which passed. The BEFORE count is traced from the dev code and screenshots. The friend-request part of it was **not** run end to end.

## Acceptance
| Criterion | Evidence | Status |
|---|---|---|
| `reason` decodes when present, `null` or missing | `BlendReasonDecodingTests` (3 pass); live backend returns `"reason": null` | PROVEN |
| First pick = first rec; Another pick cycles with no extra request | `BlendPickDeckTests`, `BlendPickModelTests.loadUsesInjectedFetchOnceAndShowsFirst` (fetch called once) | PROVEN (unit) |
| Empty / error states | `BlendPickModelTests.noResultsIsEmptyState`, `fetchFailureIsErrorState` | PROVEN (unit); not seen on device |
| "Why this pick" line shown when reason exists, hidden when nil | hidden: after-pick-card.png (backend sends null); shown: code path only | PARTIAL: nil case PROVEN, non-nil case NOT_PROVEN on device |
| Find a movie → pick → Where to watch → We watched it → rate → done | Maestro 08 passes | PROVEN |
| Add any user by username, friends first | `BlendInviteTests.candidates…` (unit); Maestro 08 adds non-friend `w2b` | PROVEN |
| Share invite text | `BlendInviteTests.shareText…` | PROVEN (unit); share sheet not opened on device |
| Create + add on one screen, default name | after-create-with-member.png, Maestro 08 | PROVEN |
| List: avatars, count, CTA, empty line | after-blend-list.png; empty line from code only (account now has blends) | PROVEN / empty state NOT_PROVEN on screen |
| Full unit target green | 132 passed, 0 failed (`unit-tests.log`) | PROVEN |
| Maestro 04 + 08 pass | `maestro-04.log`, `maestro-08.log` | PROVEN |

## Commands and results
SIM = `9B416FD5-FB4B-46BF-B7C4-B9F1E85BCA22`; DD = `/Users/jonathanyang/cursor-work/blnd-2.0-dd-f4`; logs in `~/cursor-work/blnd-2.0-artifacts/blends/`.
- Build: `xcodebuild -project blnd_ios.xcodeproj -scheme blnd_ios -configuration Debug -destination id=$SIM -derivedDataPath $DD API_BASE_URL=http://localhost:8000 build` → BUILD SUCCEEDED (before and after)
- Unit: same with `test -only-testing:blnd_iosTests` → TEST SUCCEEDED, 132 passed / 0 failed, including all 13 new `BlendsTests.swift` tests
- `maestro --device $SIM test -e EMAIL=… -e PASSWORD=… -e USERNAME_B=w2b .maestro/08_blend_find_movie.yaml` → all steps COMPLETED
- `maestro --device $SIM test -e EMAIL=… -e PASSWORD=… .maestro/04_create_blend.yaml` → all steps COMPLETED
- Screenshots: `before-{blend-list,blend-detail,pick-card,where-to-watch,log-sheet}.png`, `after-{blend-list,create-with-member,blend-detail,pick-card,where-to-watch,log-sheet,logged}.png`. Dev has no pick card, so `before-pick-card` shows the blend reel. The before blend (id 109, A + B) was seeded through the API, because the dev UI cannot add a non-friend.

Tests-first note: `BlendsTests.swift` was written before `reason` and the pick and invite types existed, so the first state was a compile failure (red). It turned green after the model was added.

## Notes / risks
- `POST /groups/{id}/members` lets any member add any user without their consent; this is existing backend behaviour, and the UI now makes it easy. Consider an accept step or a block check server-side.
- `/recommendations` (the pick) and `/recommendations/feed` (the reel) can rank differently, so the pick is not always the first reel card.
- The Maestro tap on `rating.star.4` hits the left half of the star, so it records 3.5★. That is how the existing StarRatingInput already works.

## Proposal: invite code (not built)
Sharing an `@username` still makes B type something. To get to a one-tap join:
- `POST /groups/{id}/invites` → `{code, expires_at}` (owner/member only, short random code, 7-day TTL, revocable).
- `POST /groups/join {code}` → adds the caller and returns `GroupDetailResponse`; rate-limited, with `paywall` handling the same as `addMember`.
- The app shares `https://<real universal-link domain>/j/<code>` once a domain with an AASA file exists. Until then the share text carries the code and the Blends tab gets a "Join with code" field.
With this, the path for B is: open link → joined (0 typing), and A no longer needs to search for B.
