# House Push Notifications Production Foundation Implementation Plan

> **Транспорт изменён после замеров на проде (2026-09-03).** Задачи ниже
> описывают доставку через Redis и очередь Celery `push`. На боевом сервере
> эта связка не помещается в память, поэтому доставка переведена на очередь
> в PostgreSQL (`PushOutbox`) и процесс `manage.py run_push_worker`.
> Действующее описание — в `backend/README.md`; план сохранён как история.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and deploy the complete House push foundation through a disabled production Firebase transport.

**Architecture:** PostgreSQL Notification rows remain authoritative; committed rows enqueue IDs into an isolated Redis `push` queue consumed by one solo Celery worker. Backend device/preferences/price-drop services and Flutter Firebase lifecycle share stable routing contracts and remain no-op when configuration is absent.

**Tech Stack:** Django 5, DRF, PostgreSQL 16, Celery, Redis, Firebase Admin, Flutter, firebase_messaging, flutter_local_notifications, pytest, flutter_test, systemd.

**Spec:** `docs/superpowers/specs/2026-09-03-push-notifications-foundation-design.md`

## Global Constraints

- PostgreSQL Notification is the source of truth; Redis is an ephemeral push broker only.
- Production starts with `PUSH_ENABLED=0`; disabled mode never reads Firebase credentials.
- Only `notifications.deliver_notification_push` routes to queue `push`.
- The production worker consumes only `push`, uses solo pool and concurrency 1, and has prefetch multiplier 1.
- Never start Celery Beat or a default-queue worker.
- Push/enqueue/provider failure cannot fail message send or listing update.
- Price-drop requires active listing, positive prices, same currency, and lower new price.
- Price-drop recipients are favorite union views within 30 days, minus owner, one row per user/event.
- Existing `new_message_enabled` and legacy API/type values remain compatible.
- No Firebase credential or full FCM token is committed or logged.
- Preserve user edits currently present in catalog media timing and Flutter ad/media files.
- Finik, seller UI, welcome UI, and unrelated catalog UI remain unchanged.

---

### Task 1: Durable Notification Events, Devices, and Preferences

**Files:**
- Modify: `backend/apps/notifications/models.py`
- Modify: `backend/apps/notifications/serializers.py`
- Modify: `backend/apps/notifications/services.py`
- Modify: `backend/apps/notifications/views.py`
- Modify: `backend/apps/notifications/urls.py`
- Modify: `backend/tests/test_notifications.py`
- Create: `backend/apps/notifications/migrations/0005_push_foundation.py`

**Interfaces:**
- Produces: `Notification.event_key: str`, `DeviceToken.device_id/locale/timezone`, `NotificationSettings.price_drop_viewed_enabled`.
- Produces: `register_device(user, token, platform, app_version="", device_id="", locale="ru", timezone_name="Asia/Bishkek") -> DeviceToken`.
- Produces: authenticated canonical device register/current-deactivate endpoints.

- [ ] **Step 1: Write failing model/service/API tests**

Add tests proving event-key uniqueness per user, two users may share an event key,
device-ID token refresh updates one row, device/account reassignment is atomic, current
device deactivation cannot affect another user, locale/timezone validation, canonical and
legacy endpoints, and preference alias behavior.

- [ ] **Step 2: Verify RED**

Run:

```bash
cd backend && .venv/bin/pytest tests/test_notifications.py -v --no-cov
```

Expected: failures for missing fields, endpoint, and preference alias.

- [ ] **Step 3: Implement the model and API contract**

Add nullable/blank device metadata, conditional `(user, event_key)` uniqueness, the
viewed-price preference, transactional registration by installation ID, authenticated
deactivation, and compatibility URL aliases. Do not expose `user_id` or token lists.

- [ ] **Step 4: Generate and inspect the migration**

Run:

```bash
cd backend && .venv/bin/python manage.py makemigrations notifications
cd backend && .venv/bin/python manage.py makemigrations --check
```

Expected: one migration followed by `No changes detected`.

- [ ] **Step 5: Verify GREEN**

Run the Task 1 pytest command again; expected all selected tests pass.

### Task 2: Authenticated View History and Price-Drop Fan-out

**Files:**
- Modify: `backend/apps/engagement/models.py`
- Modify: `backend/apps/engagement/services.py`
- Modify: `backend/apps/engagement/views.py`
- Modify: `backend/apps/catalog/services.py`
- Modify: `backend/config/settings.py`
- Modify: `backend/apps/notifications/services.py`
- Modify: `backend/apps/notifications/tasks.py`
- Modify: `backend/tests/test_favourites.py`
- Modify: `backend/tests/test_price_drop_notifications.py`
- Modify: `backend/tests/test_notifications.py`
- Create: `backend/apps/engagement/migrations/0006_viewhistory_view_count.py`

**Interfaces:**
- Consumes: `Notification.event_key` and `NotificationSettings.price_drop_viewed_enabled`.
- Produces: `note_view(user, listing) -> ViewHistory | None` with atomic `view_count` increment.
- Produces: `notify_listing_price_drop(listing, old_price, new_price, *, event_key, old_currency, event_at=None) -> list[Notification]`.

- [ ] **Step 1: Write failing view-history tests**

Cover first authenticated view, repeat count/timestamp, anonymous no-row behavior, and
authentication requirement for reading/deleting history.

- [ ] **Step 2: Verify view tests fail for the intended missing behavior**

Run:

```bash
cd backend && .venv/bin/pytest tests/test_favourites.py -v --no-cov
```

- [ ] **Step 3: Implement authenticated view tracking and migration**

Keep `viewed_at` as the last-view API field, add `view_count`, atomically update repeat
views, and remove all fallback-to-first-user behavior from view history.

- [ ] **Step 4: Write failing price-drop tests**

Cover favorite, recent viewed-only, favorite-and-viewed union, owner exclusion, stale
view, equal/increased/zero price, currency change, payload amount/percentage/reason/time,
same-event rerun, and recovery followed by an identical legitimate transition.

- [ ] **Step 5: Verify price-drop tests fail**

Run:

```bash
cd backend && .venv/bin/pytest tests/test_price_drop_notifications.py -v --no-cov
```

- [ ] **Step 6: Implement event-driven fan-out**

Use `PRICE_DROP_VIEW_WINDOW_DAYS`, favorite/view ID sets, stable audit-derived event keys,
one Notification per recipient, same-currency checks, structured payload, and existing
cover helpers. Remove the duplicate daily scan and its Beat entry.

- [ ] **Step 7: Verify Task 2 GREEN**

Run both Task 2 test files and `makemigrations --check`; expected all pass and no model drift.

### Task 3: Isolated Push Task and Firebase Provider

**Files:**
- Modify: `backend/pyproject.toml`
- Modify: `backend/config/celery.py`
- Modify: `backend/config/settings.py`
- Modify: `backend/.env.example`
- Modify: `backend/apps/notifications/push.py`
- Modify: `backend/apps/notifications/tasks.py`
- Modify: `backend/apps/notifications/services.py`
- Modify: `backend/tests/test_notifications.py`
- Create: `backend/tests/test_push_routing.py`

**Interfaces:**
- Produces: task `notifications.deliver_notification_push(notification_id: int) -> int` always routed to `push`.
- Produces: `send_notification_push(notification) -> PushDeliveryResult`.
- Produces: lazy `get_push_provider() -> PushProvider | None`.

- [ ] **Step 1: Write failing routing/disabled/provider tests**

Assert the task route is `push`, worker prefetch is 1, ignored results are not stored,
disabled mode never loads credentials/provider, preferences are honored by reason,
RU/KY payloads are grouped, invalid tokens deactivate, and transient exceptions request
bounded retry.

- [ ] **Step 2: Verify RED**

Run:

```bash
cd backend && .venv/bin/pytest tests/test_notifications.py tests/test_push_routing.py -v --no-cov
```

- [ ] **Step 3: Implement transport configuration and provider abstraction**

Declare `push` beside `default`, route the one delivery task centrally, set prefetch 1,
keep `ignore_result=True`, add explicit push/provider/project/credential settings, move
`firebase-admin` into tracked production dependencies, and initialize Firebase only in
enabled delivery.

- [ ] **Step 4: Implement bounded delivery behavior**

Load Notification by ID, evaluate master/type/reason settings, group active devices by
locale, send compact messages, deactivate permanent failures, retry transient failures,
and log only counts/IDs/error classes.

- [ ] **Step 5: Verify GREEN**

Run the Task 3 tests; expected all pass with no Firebase credential.

### Task 4: Message Payload and Existing Lifecycle Types

**Files:**
- Modify: `backend/apps/messaging/services.py`
- Modify: `backend/apps/catalog/moderation/services.py`
- Modify: `backend/apps/catalog/tasks.py`
- Modify: `backend/apps/engagement/tasks.py`
- Modify: `backend/apps/billing/tasks.py`
- Modify: `backend/apps/notifications/models.py`
- Modify: `backend/tests/test_message_notifications.py`
- Modify: `backend/tests/test_moderation.py`
- Modify: `backend/tests/test_engagement.py`

**Interfaces:**
- Consumes: canonical Notification types and delivery task.
- Produces: new-message payload with conversation/listing/sender/display-name/preview.
- Produces: canonical types only where corresponding domain lifecycle already exists.

- [ ] **Step 1: Write failing message/type tests**

Assert capped preview in payload, recipient-only creation, exact conversation routing
data, canonical saved-filter/moderation/expiry/subscription types, and legacy preference
compatibility.

- [ ] **Step 2: Verify RED**

Run:

```bash
cd backend && .venv/bin/pytest tests/test_message_notifications.py tests/test_moderation.py tests/test_engagement.py -v --no-cov
```

- [ ] **Step 3: Implement minimal canonical event mappings**

Preserve existing business behavior and copy; change only types/payload fields needed by
the notification contract. Do not activate any scheduled job.

- [ ] **Step 4: Verify GREEN**

Run the Task 4 tests; expected all pass.

### Task 5: Controlled Test Command and Documentation

**Files:**
- Create: `backend/apps/notifications/management/__init__.py`
- Create: `backend/apps/notifications/management/commands/__init__.py`
- Create: `backend/apps/notifications/management/commands/send_test_push.py`
- Create: `backend/tests/test_send_test_push.py`
- Modify: `backend/README.md`
- Modify: `backend/.gitignore`
- Modify: `backend/.env.example`

**Interfaces:**
- Produces: `python manage.py send_test_push --user-id <id>`.

- [ ] **Step 1: Write failing command tests**

Assert disabled mode exits cleanly without creating a row, enabled mode requires valid
provider and active device, accepts no hardcoded user, and queues exactly one controlled
Notification through the normal service.

- [ ] **Step 2: Verify RED**

Run:

```bash
cd backend && .venv/bin/pytest tests/test_send_test_push.py -v --no-cov
```

- [ ] **Step 3: Implement command and owner runbook**

Document exact backend variables, secret path/permissions, disabled lifecycle, enabling
steps, safe test command, and masked logging. Ignore all files under `secrets/` without
creating a fake JSON credential.

- [ ] **Step 4: Verify GREEN**

Run the Task 5 test; expected all pass.

### Task 6: Flutter Firebase Lifecycle and Shared Deep Links

**Files:**
- Modify: `flutter_app/pubspec.yaml`
- Modify: `flutter_app/lib/main.dart`
- Modify: `flutter_app/lib/app/app.dart`
- Modify: `flutter_app/lib/app/app_state.dart`
- Modify: `flutter_app/lib/data/api_client.dart`
- Modify: `flutter_app/lib/data/chat_models.dart`
- Modify: `flutter_app/lib/ui/pages/notifications_page.dart`
- Create: `flutter_app/lib/notifications/push_config.dart`
- Create: `flutter_app/lib/notifications/notification_destination.dart`
- Create: `flutter_app/lib/notifications/push_service.dart`
- Modify: `flutter_app/android/app/src/main/AndroidManifest.xml`
- Modify: `flutter_app/ios/Runner/Info.plist`
- Create: `flutter_app/ios/Runner/Runner.entitlements`
- Modify: `flutter_app/ios/Runner.xcodeproj/project.pbxproj`
- Create: `flutter_app/test/push_config_test.dart`
- Create: `flutter_app/test/notification_destination_test.dart`
- Modify: `flutter_app/test/app_state_test.dart`

**Interfaces:**
- Consumes: canonical device APIs and compact FCM data.
- Produces: `PushConfig.isConfigured`, `NotificationDestination.fromData`, and `PushService` lifecycle.
- Produces: `ListingApiClient.registerPushDevice(...)` and `deactivateCurrentPushDevice(...)`.

- [ ] **Step 1: Add packages and write failing pure-Dart tests**

Test disabled/incomplete platform config, exact chat/listing destinations, unknown payload
rejection, and AppState before-logout hook ordering.

- [ ] **Step 2: Verify RED**

Run:

```bash
cd flutter_app && flutter pub get
cd flutter_app && flutter test test/push_config_test.dart test/notification_destination_test.dart test/app_state_test.dart
```

- [ ] **Step 3: Implement config, API, routing, and lifecycle**

Initialize Firebase only for complete Dart defines, persist an installation UUID,
request permission once after authentication, register/refresh token with locale/timezone,
deactivate/delete token before logout, show foreground local notifications, and funnel
foreground/background/cold-start taps through the shared parser and existing navigator.

- [ ] **Step 4: Add Android/iOS declarations without credentials**

Declare Android notification permission/channels and iOS remote-notification background
mode/entitlement. Do not add real native Firebase config files.

- [ ] **Step 5: Verify GREEN and compile**

Run:

```bash
cd flutter_app && dart format --output=none --set-exit-if-changed lib test
cd flutter_app && flutter analyze
cd flutter_app && flutter test
cd flutter_app && flutter build apk --debug
```

Expected: all commands exit zero without Firebase variables.

### Task 7: Backend Verification, Repo Parity, and Git Delivery

**Files:**
- Modify: `backend/tests/snapshots/openapi.json` through the existing schema update command.
- Modify: Repo B files corresponding to tracked `backend/` changes.

**Interfaces:**
- Consumes: all previous backend and Flutter work.
- Produces: matching backend trees in Repo A and Repo B.

- [ ] **Step 1: Regenerate and review OpenAPI**

Run `cd backend && .venv/bin/python scripts/update_schema_snapshot.py`, then confirm only
intended notification/device/settings schema changes.

- [ ] **Step 2: Run targeted backend verification**

```bash
cd backend && .venv/bin/pytest tests/test_notifications.py tests/test_push_routing.py tests/test_send_test_push.py tests/test_message_notifications.py tests/test_price_drop_notifications.py tests/test_favourites.py tests/test_moderation.py tests/test_engagement.py -v --no-cov
cd backend && .venv/bin/ruff check apps config tests
cd backend && .venv/bin/ruff format --check apps config tests
cd backend && .venv/bin/python manage.py check
cd backend && .venv/bin/python manage.py makemigrations --check
```

- [ ] **Step 3: Review diffs and commit only task-owned files**

Use `git diff`, `git diff --check`, and selective `git add`; preserve existing unstaged
media/ad changes. Push Repo A main only after verification.

- [ ] **Step 4: Mirror backend diff into a clean temporary Repo B clone**

Apply the Repo A `backend/` diff with the prefix removed, run the same backend checks,
commit to Repo B main, and push. Compare checksums for every changed backend file.

### Task 8: Safe Production Deployment and Isolated Worker

**Files:**
- Create in Repo B: `deploy/systemd/house-push-worker.service`
- Modify on production: `/etc/redis/redis.conf`
- Create on production: `/etc/systemd/system/house-push-worker.service` from tracked template.
- Modify on production: `/root/house-backend/.env` with disabled non-secret contract.

**Interfaces:**
- Consumes: pushed Repo B main.
- Produces: healthy disabled push transport on production.

- [ ] **Step 1: Recheck resources and production cleanliness**

Capture `free -m`, swap, disk, top RSS, Git status/HEAD, and origin state. Abort on dirty
or non-fast-forward production state.

- [ ] **Step 2: Back up database, environment, and current revision**

Create timestamped restricted files under `/root/backups/house-push/`: PostgreSQL custom
dump, `.env` copy mode 600, and HEAD text. Verify dump with `pg_restore --list`.

- [ ] **Step 3: Fast-forward deploy and verify Django**

Pull Repo B main, install declared dependencies in `/root/venv`, apply migrations, run
`manage.py check` and `makemigrations --check`, configure `PUSH_ENABLED=0`, prepare a mode
700 `secrets/` directory, and restart Gunicorn because code/settings changed.

- [ ] **Step 4: Install/configure Redis locally**

Install the distro package only if absent; set localhost bind, protected mode, 32 MB
noeviction, `appendonly no`, and `save ""`. Start the standard service; verify PING and
that port 6379 is bound only to loopback. Measure RSS/free/swap.

- [ ] **Step 5: Foreground worker smoke**

Run the exact solo `-Q push` command in foreground, inspect registered delivery task and
active queue, enqueue a controlled existing Notification ID, and verify disabled exit
without Firebase initialization or unrelated task execution.

- [ ] **Step 6: Enable the dedicated systemd worker**

Install the tracked unit, daemon-reload, enable/start `house-push-worker`, verify active
queue `push` only, and prove no Beat/default worker process exists.

- [ ] **Step 7: Measure and enforce the safety gate**

Measure immediately and after 3–5 minutes idle: Redis/Celery RSS, available RAM, swap,
journal disk use, kernel OOM/memory-pressure logs, Gunicorn status, and HTTP API health.
If available is below 64 MB or pressure grows, disable the worker and execute only the
spec's DB PushOutbox fallback.

- [ ] **Step 8: Final disabled end-to-end smoke**

Create one controlled test Notification for a dedicated test user only when safely
identifiable; otherwise use an existing owned test fixture in a rolled-back shell. Prove
enqueue to `push`, worker disabled/no-op result, retained Notification row where applicable,
and no Firebase credential access. Recheck Git cleanliness and service health.

### Task 9: Final Evidence and Owner Handoff

**Files:**
- No code files; collect command output and final Git SHAs.

**Interfaces:**
- Produces: the requested production foundation report and exact Firebase enablement contract.

- [ ] **Step 1: Re-run final local verification**

Run the complete targeted backend and Flutter commands from Tasks 6–7 and read every exit
status before making completion claims.

- [ ] **Step 2: Re-run final production verification**

Capture active services/queues, no Beat/default worker, loopback Redis binding, disabled
push settings by presence (not secret values), resource metrics, Django check, migrations,
Gunicorn health, and Repo B clean HEAD.

- [ ] **Step 3: Produce the required report**

Report audit, architecture, devices, price-drop/view behavior, preferences, types,
deeplinks, Flutter, production resources, backups, migrations, tests, Repo A/Repo B SHAs,
and the exact backend/Android/iOS owner-provided variables and Firebase Console sources.
