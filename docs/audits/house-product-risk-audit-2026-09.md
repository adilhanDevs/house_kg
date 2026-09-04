# House KG — Product/Codebase Risk Audit

Date: 2026-09-04
Scope: read-only audit, no product logic changed, no deploy, no infra changes.
HEAD: `5bf0eb5` (origin/main, clean except this doc + an unrelated local `.gitignore` edit for `google-services.json`).

---

## EXECUTIVE SUMMARY

The codebase is in noticeably good shape for its stage: idempotency is correctly
implemented on every money-moving and message-sending workflow, soft-delete/anonymization
is used correctly for listings and accounts, and the push-notification design
(no Celery/Redis broker, deliberate `skipped_disabled` outbox state) is a rare example
of an architectural decision that already accounts for the production constraint that
provoked it (**production runs on ~458MB RAM** — this fact should drive every future
infra decision).

That said, three classes of real risk stand out:

1. **A live server-identity confusion** that this session itself almost fell into:
   an unrelated SSH host (`mtl-server` / `147.182.243.58`) was nearly used to receive
   a Firebase production secret. It was blocked only by an unrelated network restriction,
   not by any check in the process. See PRODUCTION HOST CONFIG below — this is the
   single most important finding in this audit precisely because it already almost happened.
2. **Two hardcoded secret-shaped defaults committed to git history** in
   `backend/config/settings.py` (DB URL with password, Django `SECRET_KEY`). Both are
   fail-open only if the real env var is ever *unset* in production — but the values are
   permanently in git history and one of them uses what looks like a personal password
   pattern, worth confirming isn't reused elsewhere.
3. **The Reels feed silently ignores catalog filters** (`ReelsRecommendationsView` never
   builds `active_filters`, unlike `ListingRecommendationsView`) — a direct regression of
   the same bug class the last recommendations fix (`68ce5b7`) just closed for the listings
   feed. This is a one-line, high-confidence fix.

Everything else found is real but bounded: unbounded PageController accumulation in Reels,
an event table with no retention policy, a stale OpenAPI snapshot, 14 tests asserting an
intentionally retired moderation flow, and the expected pre-launch Android/iOS release gaps
(debug signing, cleartext traffic allowed).

---

## PRODUCTION HOST CONFIG

**Expected House production (per project docs/plans):** `139.59.224.34`
(`ssh root@139.59.224.34`, path `/root/house-backend`), documented repeatedly in
`docs/superpowers/plans/2026-09-02-listing-messaging.md` (migration/deploy commands,
`curl http://139.59.224.34/api/v1/...` smoke tests). Independently corroborated by
`flutter_app/ios/Runner/Info.plist`'s `NSExceptionDomains` cleartext exception, which is
scoped to `139.59.224.34` — i.e. the app itself is built to talk to that IP.

**`147.182.243.58` (alias `mtl-server`, user `mtl`):** appears **nowhere** in House KG
docs, plans, deploy scripts, or the domain model. It is the only `Host` entry in this
machine's `~/.ssh/config`, unrelated in name (`mtl`, not `house`/`root`) and user
(non-root `mtl`, vs. documented `root@139.59.224.34`). There is no evidence this host has
anything to do with House KG.

**⚠️ Near-miss this session:** immediately before this audit, a request to transfer the
Firebase Admin service-account JSON to "production" was — with user confirmation — pointed
at `mtl-server` (147.182.243.58) because it was the only configured SSH alias available.
The transfer did not happen only because outbound port 22 to that IP is blocked at the
sandbox network layer (port 80/443 to the same host work fine, confirming it's a real,
reachable, unrelated server, not a dead IP). **No secret was actually sent.** Going
forward: verify the real House production host explicitly (139.59.224.34) before any
future secret transfer, and do not rely on "the only SSH alias present" as a signal of
correctness.

---

## P0

**1. Server-identity confusion risk (see above).** Not a code bug, but the highest-value
finding: a wrong-host secret transfer was one blocked network call away from happening.
FIX: before any future SSH-based secret/deploy action, require an explicit, user-typed
hostname/IP match against a documented list (e.g. this audit doc), not inference from
whatever `~/.ssh/config` happens to contain.

**2. Hardcoded DB credential default in git history.**
`backend/config/settings.py:130` — `DATABASE_URL` falls back to a literal
`postgres://quantum_user:<password>@localhost:5432/quantum_db` if the env var is unset.
Committed in `a8734f9` (2026-09-02). Fails open to a real, working credential rather than
crashing, which defeats "no secrets in code." The password matches a personal-password
naming pattern — confirm it is not reused as a real account password anywhere, and rotate
the local role's password regardless since it's now permanently in git history.
FIX: `env.db("DATABASE_URL")` with no default (fail fast if unset), or a default that
points at an unreachable/obviously-fake host.

---

## P1

**3. `SECRET_KEY` has a static hardcoded fallback.** `backend/config/settings.py:38`,
committed `c864a4f` (2026-09-02). If `DJANGO_SECRET_KEY` is ever unset in prod, every
deployment silently shares the same signing key (sessions, CSRF, password-reset tokens).
FIX: remove the default; raise `ImproperlyConfigured` if unset.

**4. Reels feed does not apply catalog filters before ranking.**
`backend/apps/recommendations/views.py:93-100` — `ReelsRecommendationsView.get()` builds
`RecommendationContext(..., require_video=True)` and never populates `active_filters`,
unlike `ListingRecommendationsView` (lines 52-65) which explicitly extracts and passes
them. `CandidateGenerator.get_candidates()` only applies `ListingFilterSet` when
`context.active_filters` is truthy — so Reels currently ignores `kind`, `price_max`,
`rooms`, etc. entirely. This is the exact bug class fixed for the listings feed in
`68ce5b7` ("apply catalog filters before personalized ranking"), just not ported to Reels.
FIX (verified minimal, ~6 lines): copy the `active_filters` dict-comprehension block from
`ListingRecommendationsView` into `ReelsRecommendationsView` before constructing the
context. TEST: add a Reels-feed sibling of
`tests/test_recommendations_filters.py::test_kind_filter_is_strict`.

**5. Android release APK is signed with the debug keystore.**
`flutter_app/android/app/build.gradle.kts:28-34` — explicit `// TODO` acknowledging this.
Fine for closed testing (already the accepted state per project context), but **must**
change before Play Store or any public distribution — a debug-signed APK can be
re-signed/tampered with no detection.

**6. Cleartext traffic allowed on both platforms.**
Android: `AndroidManifest.xml` `android:usesCleartextTraffic="true"`. iOS:
`Info.plist` `NSAllowsArbitraryLoads = true` plus an explicit exception for
`139.59.224.34`. This means the app currently talks to production over **plain HTTP**,
not HTTPS — auth tokens, OTP codes, and payment intents are interceptable in transit on
any hostile network. This is a real, live risk today, not just a pre-launch checklist
item, since it's already pointed at the real production IP.

**7. Flutter: unbounded `PageController` accumulation in the Reels feed.**
`flutter_app/lib/ui/pages/video_page.dart:83` — `_horizontalControllers` is a
`Map<int, PageController>` keyed by feed index, populated via `putIfAbsent` and only
disposed in `dispose()` (i.e. when the whole Reels screen closes), never pruned as the
user scrolls past old entries. Confirmed memory-growth pattern after 30+ swipes.
FIX: keep only current ±1 controllers, dispose the rest as the user scrolls.

**8. Flutter API client: token-refresh failure is silently swallowed.**
`flutter_app/lib/data/api_client.dart` — the `catch (_) { _isRefreshing = false; }` block
around the 401-refresh retry has no logging and no surfaced error; a broken refresh leaves
the caller with a bare stale 401 and no diagnostic trail. Related: `MultipartRequest`
uploads (media/video) are explicitly *not* retried after a successful token refresh
(body already consumed) — a token expiring mid-upload silently loses the whole upload.

---

## P2

- **Messaging IDOR at the view layer.** `apps/messaging/views.py:98,119` —
  `MessageListCreateView.post()` / `ConversationReadView.post()` fetch the `Conversation`
  via plain `get_object_or_404(pk=...)` before the service layer's ownership check runs.
  The end result is still a 404 for strangers (service layer catches it), but the object
  is loaded and touched before authorization — tighten by fetching through
  `conversation_for_participant(user, conversation_id)` directly in the view.
- **Finik webhook payment lookup has a fallback to a raw-payload `payment_id`.**
  `apps/billing/payments.py:249-266` — primary lookup is by `provider_ref`; if that
  misses, it falls back to treating client-echoed payload fields as a DB primary key
  lookup. Provider signature verification should make this hard to abuse, but the
  fallback path itself is unnecessary risk surface — prefer failing the lookup over
  trusting payload-echoed PKs.
- **`RecommendationEvent` dedup only applies when `client_event_id` is non-null.**
  `apps/recommendations/models.py` unique constraint is conditional on
  `client_event_id__isnull=False`; events sent without one (older client, or a retry that
  drops the id) accumulate as true duplicates with no server-side backstop, skewing
  `TasteProfileService` aggregation.
- **No retention/cleanup job for `RecommendationEvent`.** Grows unboundedly; rough
  estimate (SUSPECTED, based on Flutter event-emission call sites) — order of
  3k rows/day at 100 DAU, scaling roughly linearly to ~300k/day at 10k DAU. No Beat task
  prunes old rows. Worth a 90-day retention job before any real growth.
- **`TasteProfileService.build_profile()` loads up to 500 raw events per request and
  aggregates in Python** (`apps/recommendations/services.py:360-390`) rather than caching
  or using a materialized/async-updated profile — fine at current scale, will show up as
  latency once individual users accumulate thousands of events.
- **Flutter: `recommendationSessionId` is not rotated on logout.**
  `lib/app/app_state.dart` clears filters/favourites/wallet state on `logout()` but the
  `late final recommendationSessionId` is never regenerated, so a new user logging in on
  the same device continues the previous account's personalization session server-side.
- **Flutter: double-tap-to-favorite has no in-flight guard** — two near-simultaneous taps
  can both call `toggleFavourite`; the backend's `get_or_create` makes this safe
  server-side, but the client can show flickering/incorrect optimistic state.
- **Media/listing hard-deletes for `ListingMedia`** (vs. the correctly soft-deleted
  `Listing` itself) have no audit-log entry before `media.delete()` — acceptable for
  storage cleanup, but leaves no trail if a user disputes "I didn't delete that photo."
- **iOS push/APNs is entirely unconfigured** — no blocker for Android-only testing, but
  a real gap before any iOS release; `NSAllowsArbitraryLoads=true` will also cause App
  Store review rejection on its own.
- **OpenAPI contract snapshot is stale** (`tests/test_openapi_contract.py`) — 9
  newly-required fields (`owner_id`, `cover_url`, `provider_item_id`,
  `new_listing_match_enabled`) were added without running `make schema-update`. Likely
  fine, but confirm none of them should actually be optional before regenerating.

---

## SECURITY

Auth/ownership checks are correctly enforced almost everywhere sampled (favourites,
wallet, promotions, subscriptions, reviews, account deletion all check `request.user`
ownership before mutating). The one confirmed gap is the messaging view-layer IDOR above
(P2, low actual exposure since the service layer still blocks it). No `User.objects.first()`
style fallback, no client-supplied `user_id`/`owner_id` acceptance found in the sampled
write paths. The two hardcoded-default secrets (P0/P1 above) are the dominant security
finding this cycle — both are silent-fail-open patterns, which is the dangerous variant
(a crash-on-missing-config would have been safer than a working fallback).

## PAYMENTS

Finik integration is backend-authoritative: wallet credit happens only after
server-side verification of the callback, `Idempotency-Key` is enforced and tested for
topup/promotion/subscription purchases (`test_topup_requires_idempotency_key`,
`test_repeated_idempotency_key_does_not_charge_twice`, etc.), and duplicate-charge
protection is backed by real DB unique constraints, not just client discipline. The one
soft spot is the payload-PK fallback in the webhook handler noted in P2 — narrow, but
unnecessary.

## PUSH

Design is deliberately broker-free specifically because of the 458MB production RAM
ceiling (documented in `backend/README.md`), and the "disabled" state is handled
correctly: rows touched while `PUSH_ENABLED=0` are marked `skipped_disabled` and never
re-queued, so flipping the flag on later only delivers *new* events, not a backlog — this
was verified directly against the code and its design-rationale comment, not just assumed.
The only real caveat is operational, not code: this guarantee only holds if the
`run_push_worker` loop process is continuously running (it's a supervised long-lived loop,
not a cron job) — worth confirming it's under systemd supervision in production, not
manually started.

## RECOMMENDATIONS

Core design (candidate generation → strict filter → feature scoring → diversification) is
sound and the listings-feed filter-strictness bug was correctly fixed. The Reels-feed gap
(P1 above) is the standout defect — same bug, different endpoint, not yet ported. Cursor
pagination is intentionally stateless (`"next"` sentinel + session-scoped seen-exclusion);
this is fine within a single session but means a cursor is meaningless if replayed across
sessions — not a bug today since nothing does that, but worth documenting as a contract
constraint. "Seen exhaustion" correctly returns an empty page rather than looping — biggest
risk here is just that this isn't documented as expected behavior anywhere client-visible.

## CATALOG/FILTERS

Filter matrix (built by the recommendations/catalog research pass) shows every
Flutter-sent filter param is accepted and actually applied by `ListingFilterSet` — no
silent no-op filters found. Test coverage is uneven: only `kind`, `rooms`, and price
bounds have dedicated strictness tests; the remaining ~15 filter fields (district, area
ranges, floor position, seller_kind, series, builder, plot/commercial purpose, etc.) are
implemented and match, but untested — worth backfilling before the filter logic is
touched again.

## REELS

Concentrated risk area, consistent with recent regression history: unbounded
`PageController` map growth (P1), a stale-closure risk in `onPageChanged` when the feed
list is rebuilt mid-scroll (index capture bug, low probability but real), and a narrow
timing race between manual pause and app-lifecycle pause on lock-screen. None of these are
crashes; all are the kind of bug that shows up only after extended real-world use (30+
swipe sessions), which is exactly why they weren't caught by existing tests.

## MEDIA

Upload/delete paths are correctly transaction-wrapped on the backend; no evidence of
orphaned media on partial batch failure in the sampled code. Missing audit trail on media
hard-delete (P2) is the only gap. No client-side memory-blowup evidence found for large
video uploads, but this wasn't executed end-to-end (static read only).

## CHAT/SELLERS

Conversation creation and message sending are both correctly idempotent
(`get_or_create` on `(listing, buyer, seller)`, unique `client_message_id` per sender)
and message sending locks the conversation row (`select_for_update`) inside a transaction.
The one open item is the view-layer IDOR noted under SECURITY — narrow but worth the
one-line fix.

## FLUTTER STATE

`AppState` is a large singleton but `resetFilter()`/`logout()` correctly clear
favourites/viewed/filters/wallet-adjacent state — the one confirmed gap is
`recommendationSessionId` surviving a logout (P2), which cross-contaminates personalization
across accounts on a shared device. No evidence found of stale-response-overwrites-newer
races in the sampled providers, but this wasn't exhaustively traced through every
async call site.

## BACKEND/PERFORMANCE

No confirmed N+1 in the core listing/recommendations serialization path — the
`CandidateGenerator` already does `select_related`/`prefetch_related` for the fields the
serializer needs; the Reels view additionally patches in a video-only media prefetch
after the fact (works, but is a sign the base prefetch and the serializer's actual field
usage have drifted apart — worth consolidating rather than patching per-view). Indexes on
`Listing`, `RecommendationEvent`, `ViewHistory`, and `Favourite` are present and match the
actual filter/order fields used; no unindexed hot-path field found. `TasteProfileService`'s
per-request 500-row Python aggregation is the one performance item to watch as usage grows.

## TEST GAPS

Weakest tests (see full list returned by the audit) cluster in two patterns: pure
screenshot-dump tests with zero assertions (`render_snapshots_test.dart` and two
siblings — these are manual-QA scripts mislabeled as tests, not real coverage), and a
routing test that hand-copies the real `app.dart` branching logic instead of exercising
it — the same failure shape as the historical seller-CTA bounding-box bug, just for the
pro/client profile route decision this time. `finik_payment_flow_test.dart` has two
`isA<Function>()`/`isA<Widget>()` assertions that can't fail regardless of behavior,
notably weaker than its own well-built siblings (`finik_payment_test.dart`).

**21 baseline backend test failures**, fully classified — not new breakage:
- **14 failures** = STALE TEST: `publish_listing()` intentionally goes DRAFT→ACTIVE
  directly now (moderation happens reactively on resubmission only); the moderation test
  suite still asserts the old "always creates a ModerationTask" behavior.
- **5 failures** = ENVIRONMENT DEPENDENCY: throttle tests rely on `.env` overrides
  (`OTP_PHONE_RESEND_THROTTLE`, etc.) that aren't set in this sandbox; settings fall back
  to permissive defaults.
- **1 failure** = STALE TEST: OpenAPI contract snapshot needs `make schema-update` after
  9 legitimate new fields.
- **1 failure** = test-infrastructure gap: `ListingRoom` and `PushOutbox` models have no
  factory yet, tripping the "every model has a factory" meta-test.

None of the 21 are evidence of a real product regression.

## ANDROID RELEASE

Debug-signed release build and cleartext traffic enabled (both P1 above) are the two
items that must change before any public/Play Store distribution — and cleartext, in
particular, is a live risk today since it's already pointed at the real production IP,
not just a checklist item for later. versionCode scheme is sane (monotonic, ABI-offset
handled correctly per this session's own build/verify work). No dangerous exported
components found in the manifest.

## iOS

Not build-tested. Concrete blockers if an iOS release is planned: no APNs
entitlement/Firebase iOS config (push won't work), `NSAllowsArbitraryLoads=true` will
fail App Store review on its own regardless of the push gap, and Finik's iOS SDK
integration status wasn't confirmed present.

## OPS/MEMORY

**Production runs on ~458MB RAM** — this is the single most load-bearing operational
fact in the codebase and is already correctly driving the "no Celery/Redis broker for
push" decision (documented in `backend/README.md`). Any future proposal to add Redis, a
Celery worker, a heavy ML/embedding step, or another long-running process needs to be
weighed against this ceiling explicitly — it is not a generic "future consideration," it
is a hard current constraint. The recommendations engine's `TasteProfileService` doing
per-request Python aggregation (rather than a cached/materialized profile) is the most
likely future memory/CPU pressure point if usage grows, precisely because the "just add
Redis for caching" escape hatch isn't cheaply available here.

## DEPENDENCIES

No upgrades needed now. Two items worth tracking: `firebase-admin` 7.5.0 has a
deprecation warning explicitly silenced in `pyproject.toml` because the code still uses
`MulticastMessage.tokens` (renamed to `fids` upstream) — a future major bump could break
push delivery outright rather than degrade. `finik_sdk` (Flutter) is a single-vendor,
externally-versioned payment SDK — the biggest single blocker risk for a future Flutter
engine upgrade, since its release cadence isn't in this team's control; it's already
reasonably isolated behind `FinikSdkPaymentPage`, which helps. `video_thumbnail` and
`saver_gallery` (Flutter) are the usual lower-maintenance native-plugin risk category
worth a maintenance-activity check before the next Android/iOS toolchain bump.

## APK / BUILD DISTRIBUTION

Confirmed clean: no `.apk` file and no `.finik.local.json`/secret-bearing file anywhere
in `house_kg` git history (`git log --all --diff-filter=A --name-only` checked). Current
practice (private `adilhanDevs/house-kg-builds` repo, GitHub Release with an attached
asset) keeps the APK out of the product repo entirely, which is the right call. Longer
term, committing raw APK blobs to *any* repo (even the private builds repo) will bloat
that repo's pack size release over release with no automatic pruning — a CI-artifact
system or Release-only (no committed blob) distribution would scale better, but this is
a "later" note, not urgent.

---

## TOP 10 FIXES IN ORDER

1. Stop treating "the only configured SSH alias" as production — require an explicit,
   documented host check before any future secret transfer. (process fix, not code)
2. Remove the hardcoded `DATABASE_URL` password default; rotate the underlying local
   Postgres password since it's now permanently in git history.
   — SMALL, LOW conflict risk
3. Remove the hardcoded `SECRET_KEY` default; fail fast if unset.
   — SMALL, LOW conflict risk
4. Port `active_filters` extraction into `ReelsRecommendationsView` (mirrors the existing
   fix in `ListingRecommendationsView`).
   — SMALL, LOW conflict risk
5. Disable cleartext traffic on Android (`usesCleartextTraffic=false`) and iOS
   (`NSAllowsArbitraryLoads=false`, scope the exception) once production HTTPS is
   confirmed reachable.
   — SMALL, MEDIUM conflict risk (need to confirm prod actually serves HTTPS first)
6. Bound the Reels `_horizontalControllers` map to current±1, disposing the rest on scroll.
   — SMALL/MEDIUM, LOW conflict risk
7. Log (don't silently swallow) token-refresh failures in the Flutter API client; surface
   a clear error for the multipart-upload-can't-retry case.
   — SMALL, LOW conflict risk
8. Rotate `recommendationSessionId` on logout in `AppState`.
   — SMALL, LOW conflict risk
9. Tighten the messaging view-layer IDOR (`conversation_for_participant` instead of raw
   `get_object_or_404`) and the Finik webhook's payload-PK fallback.
   — SMALL, LOW conflict risk
10. Add a 90-day retention Celery Beat task for `RecommendationEvent`, and require
    `client_event_id` (make it non-nullable) to close the dedup gap.
    — MEDIUM, LOW conflict risk

## BEFORE PUBLIC BETA

Must-fix: items 2, 3, 4, 5 above, plus real release signing (item outside the top-10
because it's an operational step — generate and use a real Play Store keystore, not a
code change). Should-fix before wider scale: items 6-10, plus backfilling filter-strictness
tests for the ~15 currently-untested filter fields and regenerating the OpenAPI snapshot.

## PRIORITIZED FIX PLAN

**PHASE 1 — must fix before public beta**
- Remove hardcoded `DATABASE_URL`/`SECRET_KEY` defaults, rotate the exposed password — SMALL, LOW
- Fix Reels `active_filters` gap + add the missing strictness test — SMALL, LOW
- Disable cleartext traffic both platforms (after confirming prod HTTPS works) — SMALL, MEDIUM
- Real release keystore for Android (ops step, not a diff) — SMALL, LOW
- Tighten messaging view-layer IDOR — SMALL, LOW

**PHASE 2 — should fix before scale**
- Bound Reels PageController accumulation — SMALL/MEDIUM, LOW
- Rotate `recommendationSessionId` on logout — SMALL, LOW
- Log token-refresh failures; handle multipart-401 explicitly — SMALL, LOW
- RecommendationEvent retention job + non-nullable `client_event_id` — MEDIUM, LOW
- Backfill filter-strictness tests for untested filter fields — MEDIUM, LOW
- Regenerate OpenAPI snapshot (`make schema-update`) after confirming the 9 new
  required fields are intentional — SMALL, LOW
- Update/retire the 14 stale moderation tests to match the publish-first design — MEDIUM, LOW

**PHASE 3 — cleanup/maintainability**
- Replace the two zero-assertion screenshot "tests" with either real assertions or
  delete them / move to a manual QA script — SMALL, LOW
- Fix the routing test that hand-copies `app.dart`'s branch logic instead of exercising it — SMALL, LOW
- Add `ListingRoomFactory`/`PushOutboxFactory` to close the factory-completeness gap — SMALL, LOW
- Consolidate the Reels-view media prefetch patch with the base `CandidateGenerator`
  prefetch instead of patching per-view — MEDIUM, LOW
- iOS Firebase/APNs setup, when an iOS release is actually planned — LARGE, LOW (isolated)
