# House KG Android push — operator and phone checks

## Current gate

Production push stays **PUSH_ENABLED=0**. The existing database outbox/worker is reused; no Redis/Celery addition is needed. A fresh Firebase Admin credential has been installed and its Google OAuth authentication validated. Physical delivery remains untested.

**Credential gate resolved on 2026-09-04.** The owner supplied a fresh matching House KG service account, absent from checked Git history. It is installed with root ownership and mode 600 in a root-owned mode-700 directory, excluded from Git, and Google OAuth authentication passed without sending a notification. The older key in builds Git history and the unrelated Downloads credential were not installed. Revocation of the previously exposed key still needs separate coordination; DB/JWT/Finik secrets were not changed.

Only target: `139.59.224.34`, hostname `house-kg-droplet`, repository `/root/house-backend`, remote `adilhanDevs/house-backend`. Run `backend/scripts/check_production_host.sh 139.59.224.34` locally before SSH. Do not use `mtl-server` or another server.

The credential installation uses `/root/house-backend/secrets` owned by root with mode 700, `firebase-service-account.json` mode 600, and existing `FCM_CREDENTIALS_FILE`. `FCM_CREDENTIALS_BASE64` remains unset and `PUSH_ENABLED=0` until the owner is ready for controlled delivery. Gunicorn and the push worker were restarted after configuring only FCM_CREDENTIALS_FILE.

## Client contract

- `POST /api/v1/notifications/devices/`: token, platform=android, random installation UUID as device_id, current app locale. Optional version/timezone metadata is omitted rather than fabricated. Server defaults apply.
- `DELETE /api/v1/notifications/devices/current/`: device_id in JSON, before auth is cleared. FCM deleteToken also invalidates the local token. Both are best effort when offline; failed network delivery cannot be proved remotely.
- Registration is serialized and remembered per process; a restart upserts the same installation. Refresh replaces the token, and resume retries failure (including profile hydration after an offline startup). Device requests capture auth and do not auto-refresh a delayed request into another account. Normal API calls refresh access credentials; push registration retries on resume if its own request receives 401.
- Permission is requested after login, at most once per installation. Denial does not block use. Granting in Android Settings takes effect on resume.
- FCM foreground events refresh the existing notification list/badge; they do not create Notification rows or navigate. Request generations prevent out-of-order refresh responses from restoring older data.
- Push data now includes authoritative string `recipient_id` from Notification.user_id, in addition to notification_id/type and existing whitelisted fields. Payloads lacking recipient_id are safely ignored by this client for navigation. Deploy the matching backend before enabling delivery.
- `new_message` uses canonical UUID conversation_id and `/conversations/detail`; `price_drop` uses listing_slug and `/listing`. No display-name identifiers. Taps wait for session hydration and a non-startup route, then consume once. Logout clears pending action; wrong recipients/malformed payloads are ignored.
- Android receives alert notifications through Firebase/Android while backgrounded. The top-level background handler only initializes Firebase and does not navigate.

Implementation reference: [Flutter FCM handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages) and [Android Google Services setup](https://firebase.google.com/docs/android/setup).

## Controlled test — credential gate resolved, owner phone required

1. Keep the global switch off while installing the APK, logging in, granting permission, and inspecting that this user's installation has an active DeviceToken. Inspect only id/user_id/platform/is_active/last_seen_at; never print token values.
2. Verify worker/gunicorn active, Django check, DB connectivity, and no pending/retry/processing backlog. Events skipped while disabled must not be requeued en masse.
3. Arrange a short, explicit test window with the owner before enabling delivery. This task does not enable production push.
4. The existing administrator-only command `manage.py send_test_push --user-id <OWNER_TEST_USER_ID>` sends a system notification to that user's active devices. It has no public endpoint and exits without creating a row while push is disabled. It checks transport only, not chat/listing navigation. Do not run it for an arbitrary or production-wide user set.
5. For navigation, use a second test account to send one real message to the owner's existing conversation. For price_drop, favourite a test listing and lower its price through the existing owner flow sufficiently to satisfy backend notification policy (use test data only).
6. Confirm one DB Notification and one outbox event for the action, then physical receipt and tap. Do not infer receipt from the worker accepting a message. Restore disabled state if the test window is closed or a failure occurs.

## Owner's phone checklist

- Install private ARM64 APK; open and log in.
- Notification permission appears once; allow. A refusal must still leave the app usable.
- Operator confirms an active token record for this installation, without showing its value.
- After the credential/test-window gate above: receive one new_message while backgrounded.
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
flutter build apk --release --split-per-abi --build-name=1.0.1 --build-number=110 --dart-define-from-file=.finik.local.json
```

Prior split build used Flutter 109: ARM64 versionCode 2109, ARMv7 1109, x86_64 4109. New Flutter build 110 yields ARM64 2110. Use an incremented unused build number for any future release.

The current release signing configuration uses the Android debug certificate. **PUBLIC DISTRIBUTION SIGNING: NOT READY.** APK contains private runtime configuration: distribute only through the verified PRIVATE house-kg-builds prerelease repository. No APK or credential belongs in the public monorepo.

## Verified release artifact (2026-09-04)

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
