# House KG Android push — operator and phone checks

## Current status

Production push is **PUSH_ENABLED=1**, enabled with owner authorization. The existing database outbox/worker is reused. The owner confirmed background new_message, cold-start new_message, and price_drop delivery/navigation on build 2110. Two subsequent regressions (system tap unread state and same-token re-login) are fixed for build 2111; the new physical retests remain pending. Do not send test pushes without the next explicit owner request.

**Credential gate resolved on 2026-09-04.** The owner supplied a fresh matching House KG service account, absent from checked Git history. It is installed with root ownership and mode 600 in a root-owned mode-700 directory, excluded from Git, and Google OAuth authentication passed without sending a notification. The older key in builds Git history and the unrelated Downloads credential were not installed. Revocation of the previously exposed key still needs separate coordination; DB/JWT/Finik secrets were not changed.

Only target: `139.59.224.34`, hostname `house-kg-droplet`, repository `/root/house-backend`, remote `adilhanDevs/house-backend`. Run `backend/scripts/check_production_host.sh 139.59.224.34` locally before SSH. Do not use `mtl-server` or another server.

The credential installation uses `/root/house-backend/secrets` owned by root with mode 700, `firebase-service-account.json` mode 600, and existing `FCM_CREDENTIALS_FILE`. `FCM_CREDENTIALS_BASE64` remains unset. Push is now enabled for the owner-authorized lifecycle tests. Gunicorn and the push worker were restarted after configuring only FCM_CREDENTIALS_FILE.

## Client contract

- `POST /api/v1/notifications/devices/`: token, platform=android, random installation UUID as device_id, current app locale. Optional version/timezone metadata is omitted rather than fabricated. Server defaults apply.
- `DELETE /api/v1/notifications/devices/current/`: device_id in JSON, before auth is cleared. Successful deactivation keeps the FCM token; local registration bookkeeping resets so the same token is registered on the next login. deleteToken is a fallback only when backend deactivation fails. Both operations are best effort when offline.
- Registration is serialized and remembered per process; a restart upserts the same installation. Refresh replaces the token, and resume retries failure (including profile hydration after an offline startup). Device requests capture auth and do not auto-refresh a delayed request into another account. Normal API calls refresh access credentials; push registration retries on resume if its own request receives 401.
- Permission is requested after login, at most once per installation. Denial does not block use. Granting in Android Settings takes effect on resume.
- FCM foreground events refresh the existing notification list/badge; they do not create Notification rows or navigate. Request generations prevent out-of-order refresh responses from restoring older data.
- Push data now includes authoritative string `recipient_id` from Notification.user_id, in addition to notification_id/type and existing whitelisted fields. Payloads lacking recipient_id are safely ignored by this client for navigation. Deploy the matching backend before enabling delivery.
- `new_message` uses canonical UUID conversation_id and `/conversations/detail`; `price_drop` uses listing_slug and `/listing`. No display-name identifiers. Taps wait for session hydration and a non-startup route, then consume once. Logout clears pending action; wrong recipients/invalid destinations are ignored. Missing or malformed notification_id still permits a valid destination but skips mark-read. A valid ID deduplicates navigation and the shared asynchronous mark-read endpoint; successful read refreshes the server-owned badge. Receipt alone never marks read.
- Android receives alert notifications through Firebase/Android while backgrounded. The top-level background handler only initializes Firebase and does not navigate.

Implementation reference: [Flutter FCM handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages) and [Android Google Services setup](https://firebase.google.com/docs/android/setup).

## Controlled retest after build 2111

Keep PUSH_ENABLED=1. Before each owner-authorized single-device test, verify gunicorn/worker, DB/API and no pending/retry/processing backlog. Never broadcast or automatically repeat. Never print device tokens.

1. Install the new private APK. Same account: login → ACTIVE; logout → INACTIVE; login with the same FCM token → ACTIVE.
2. For each new_message and price_drop test, send exactly one controlled notification only after the owner requests it. Receipt adds one unread item; tapping the system notification opens its exact destination, marks its canonical Notification read, and refreshes the bell count.
3. Repeat new_message from cold start: one destination, one mark-read. Stop after sending and wait for physical confirmation.
4. Account switch A → logout → B: only B owns the active installation; B → logout → A rebinds to A.
5. Do not alter real listing prices or create real chat messages as test fixtures without explicit owner authorization. Do not requeue old skipped events.

## Owner's phone checklist

- Install private ARM64 APK; open and log in.
- Notification permission appears once; allow. A refusal must still leave the app usable.
- Operator confirms an active token record for this installation, without showing its value.
- After the owner requests a controlled single-device test: receive one new_message while backgrounded.
- Tap: the correct existing chat opens.
- Remove the app from recents, send another message, tap: cold start opens the correct chat after startup.
- Do not use Android Settings → Force stop for this test: Android requires a manual reopen after a force stop before FCM can resume.
- Trigger a price_drop on a test listing: tap opens that exact listing.
- Receive a foreground event: screen stays in place, list/badge refresh, no duplicate database notification.
- Log out: operator confirms deactivation. Sign in as a second account on the same phone and verify the installation belongs to that account; an old notification cannot navigate into the previous account's chat.
- Report PASS/FAIL for receipt, background tap, cold-start tap, foreground behavior, and account switch. None of these physical observations are claimed by automated tests.

## Reproduce local validation/build

Use local PostgreSQL and a local-only test secret via environment; never point tests at production. The local venv lacks pytest-cov, so use `pytest -o addopts=''` with the five targeted files: test_notifications.py, test_notification_contracts.py, test_push_outbox.py, test_push_routing.py, test_send_test_push.py. Run manage.py check, makemigrations --check --dry-run, and ruff checks.

Run Flutter commands sequentially: parallel Flutter tooling can race on generated Swift package symlinks. Tests: push_coordinator_test.dart, push_app_test.dart, push_api_test.dart, push_permission_test.dart, profile_logout_test.dart, notification_badge_test.dart, notifications_chat_test.dart, price_drop_notification_test.dart.

Build from flutter_app with the existing ignored Finik config:

```sh
flutter build apk --release --split-per-abi --build-name=1.0.1 --build-number=111 --dart-define-from-file=.finik.local.json
```

Prior split build used Flutter 109: ARM64 versionCode 2109, ARMv7 1109, x86_64 4109. New Flutter build 110 yields ARM64 2110. Use an incremented unused build number for any future release.

The current release signing configuration uses the Android debug certificate. **PUBLIC DISTRIBUTION SIGNING: NOT READY.** APK contains private runtime configuration: distribute only through the verified PRIVATE house-kg-builds prerelease repository. No APK or credential belongs in the public monorepo.

## Regression fixes for build 2111 (2026-09-04)

Artifact: [private prerelease v2111](https://github.com/adilhanDevs/house-kg-builds/releases/tag/v2111), house-kg-arm64-v2111.apk, 86,175,249 bytes. SHA-256 be83e9f5980e7421ed6764672d7c6a7acf0007ceee0e5c23648f4d974feb7c1d. Client source commit 1f208ac298fdc68eaa2da6ee589dea2957c5289b. Real release build passed (Flutter 111 / Android 2111 / versionName 1.0.1 / ARM64 / minSdk 24 / targetSdk 36). apksigner passed with the same Android Debug certificate as build 2110; private testing only.

System taps previously navigated without invoking the read endpoint. The FCM payload already included canonical string notification_id, so no payload change was required. Both system and in-app taps now share AppState.markNotificationRead → POST /notifications/read/ with the exact ID. Navigation starts immediately; mark-read has a 10-second best-effort timeout. Successful responses refresh the existing server-owned notification revision/badge. Receipt, failed reads and malformed IDs do not decrement a local counter. Cold-start and opened-app callbacks consume a notification once.

Re-login failed in the backend serializer, not the client cache. Production requests returned HTTP 400; read-only validation of the stored device payload reported device_id unique. DRF's automatic uniqueness validator rejected a known installation before the existing register_device upsert could reactivate it. The validator is now disabled for this upsert key, retaining database uniqueness and authenticated-user ownership. The HTTP regression reproduces fresh registration, repeated registration, logout, unchanged-token A → A → B → A cycles and ignores a spoofed client user_id. Earlier service-only tests missed this API-level rejection.

Client registration bookkeeping already reset on logout/user change. The new AppState test proves actual registration requests with an unchanged token throughout. Normal logout now keeps the FCM token; deleteToken remains only a fallback when backend deactivation fails.

Validation: 69 focused Flutter tests; 65 backend tests in both repositories with local PostgreSQL; Django check and no migration changes; changed backend paths pass Ruff. Analyze: 128 existing diagnostics, no new diagnostics against the prior baseline. The profile-notification test fixture now places AppScope above its Navigator so pushed routes receive the same state. Mutations removing mark-read or preserving the registration memo fail their regression tests; restored code passes. Independent read-only code review found no blocking issues.

Canonical backend commit: 9f36d133f169235fadde763e3d35ef0f999a6775, pushed and deployed from adilhanDevs/house-backend. Production backup branch backup/fcm-before-relogin-fix-20260904 retains prior HEAD 61286369225489be00c5c9c3fc9085c539931621. Only gunicorn needed restart; no schema/config change. Post-deploy: gunicorn/house-push-worker active, Django/DB/Firebase Admin init pass, HTTPS config/listings 200, PUSH_ENABLED=1, pending/retry/processing backlog 0. Existing-device serializer validation now succeeds. No device was manually activated and no test notification was sent.

Physical checks for this build remain NOT TESTED: same-account relogin, system new_message read state, price_drop read state, cold-start read/deduplication, cross-account ownership. Tokens and secret configuration were not printed; only the canonical production host was contacted.

## Previous release artifact 2110 (historical, 2026-09-04)

- Private prerelease: [House KG Android FCM Test 2110](https://github.com/adilhanDevs/house-kg-builds/releases/tag/v2110), tag `v2110` in `adilhanDevs/house-kg-builds`.
- Local distributable: `/Users/adminbaike/house-kg-builds/house-kg-arm64-v2110.apk`.
- Generated APK: `/Users/adminbaike/house_kg/flutter_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Size: 86,175,249 bytes (86.18 MB); SHA-256: `b6c0ca575b2ed333a7d9226c595b7805a50c43b616892b43809e4d898b5d6d0e`.
- VersionName 1.0.1, Flutter build 110, APK versionCode 2110, applicationId kg.housekgz.house_kgz; ARM64 only; minSdk 24 / targetSdk 36.
- apksigner validation passed. Android Debug certificate SHA-256: `b9d38b4e9e68e24eac93931489dd4f00f88fb9b9ffa59ada0cc3f14165a2bd3e`, matching the previous 2109 APK.
- Client implementation commit: `d2f2755`; matching production Repo B commit: `61286369225489be00c5c9c3fc9085c539931621`.
- Flutter: 53 focused tests passed; analyze completed with 129 existing findings and no new diagnostics compared with the captured baseline.
- Backend: 64 tests passed in each repository using local PostgreSQL 16; Django check and migration checks passed; changed notification files pass ruff and formatting. Repository-wide baseline: 71 ruff issues and 12 files requiring formatting, none in changed files.
- Production after deployment: gunicorn and house-push-worker active, DB SELECT 1 passed, Django check passed, app/config and listings HTTPS returned 200; push disabled, pending/retry/processing backlog 0.

## Session security incident

During recovery inspection, the existing monorepo settings.py hardcoded Django secret fallback accidentally appeared in tool output. Its value is deliberately not repeated here. No rotation was performed in this FCM task; assess that exposure in the separate security task. Firebase Admin JSON, Finik configuration contents, DB credentials and live access/refresh tokens were not printed. No service-account credential was uploaded and no wrong server was contacted.

Credential follow-up: a fresh matching key was installed after the original release report. No secrets were printed during that follow-up, no push was sent, and PUSH_ENABLED stayed 0.
