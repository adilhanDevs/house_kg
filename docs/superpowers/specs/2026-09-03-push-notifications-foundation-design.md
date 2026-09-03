# House Push Notifications Production Foundation — Design

## Goal

Deliver production-ready push infrastructure for House while keeping PostgreSQL
`Notification` rows as the source of truth. Firebase credentials are deliberately
absent during rollout; backend, worker, and Flutter must remain healthy in a disabled
no-op mode.

## Existing System Audit

- `apps.notifications.models.Notification` already stores typed in-app notifications.
- `notify()` and `notify_many()` enqueue push after `transaction.on_commit`.
- `new_message` is created in `apps.messaging.services.send_message` and is idempotent
  through `client_message_id`.
- Event-driven favorite price-drop exists in `apps.notifications.services`, including
  an hour-window approximation of transition deduplication.
- A second legacy daily favorite-price scan exists; it would duplicate the event-driven
  path if Celery Beat were enabled.
- `DeviceToken` and `NotificationSettings` exist, but Flutter does not register tokens.
- The FCM sender is present and lazy, but production lacks `firebase-admin`, an explicit
  `PUSH_ENABLED` switch, Redis, and any Celery worker.
- `ViewHistory` already provides one row per `(user, listing)` and updates `viewed_at`.
  It lacks `view_count`; anonymous legacy code incorrectly falls back to the first user.
- Saved-filter, moderation, listing-expiry, and subscription lifecycle events already
  exist under older generic notification types.
- Flutter already maps in-app `new_message` to a conversation and listing-bearing
  notifications to listing details, but has no Firebase or local-notification plumbing.

## Architecture

```text
domain transaction
  -> PostgreSQL Notification row
  -> COMMIT
  -> on_commit(notification_id)
  -> Redis queue "push"
  -> house-push-worker (solo, concurrency 1, push queue only)
  -> preferences + active DeviceToken rows
  -> Firebase Admin provider
  -> Android/iOS
  -> shared Flutter notification destination parser
  -> existing House navigator
```

Redis is only an ephemeral push broker. It does not store notification state, task
results, or application cache data for this production worker. A broker outage may lose
a push attempt, but must not roll back messages, price changes, or Notification rows.

Only `notifications.deliver_notification_push` routes to `push`. Every other Celery task
continues to route to `default`, and no default worker or Celery Beat process is started.

## Notification and Idempotency Model

`Notification` gains an optional `event_key`. A conditional unique constraint on
`(user, event_key)` makes delivery fan-out idempotent for a domain event without changing
legacy rows. A listing price-change audit row supplies the stable event identity:
`price-drop:<audit-log-id>`. Reprocessing the same audit event creates nothing; a genuine
drop after a recovery receives a new audit ID even when old/new values repeat.

The push worker only reads an existing Notification by ID. It never creates a second
Notification row.

Standard notification types are added for existing product events:

- `new_message`
- `price_drop`
- `new_listing_match` (existing saved-filter match flow)
- `listing_approved`, `listing_rejected`
- `listing_expiring`, `listing_expired`
- `subscription_status` for the existing subscription lifecycle

Legacy enum values remain valid for old database rows and clients. Type preferences map
both legacy and canonical values to the same stored setting.

## Price Drop

A drop is eligible only when the listing is active, both prices are positive, currencies
before and after are identical, and `new_price < old_price`.

Recipients are:

```text
favorite user IDs
UNION
ViewHistory user IDs where viewed_at >= now - PRICE_DROP_VIEW_WINDOW_DAYS
MINUS
listing.owner_id
```

The default window is 30 days and is configured once in Django settings. Each recipient
gets one Notification with reason `favorite`, `viewed`, or `favorite_and_viewed`.
`price_drop_viewed_enabled=false` suppresses push only for `viewed`; favorites and
`favorite_and_viewed` continue to push when `price_drop_enabled=true`.

Payload contains listing identifiers, old/new price, currency, amount, percentage,
cover URL, address summary, reason, and event timestamp. These values are presentation
data, not a client-side business authority.

The legacy periodic price-drop scan and its Beat entry are removed so there is one
price-drop source of truth.

## View Tracking

The existing `ViewHistory` model remains the relation. It gains `view_count` and keeps
`viewed_at` as its last-view timestamp to preserve current API compatibility. Authenticated
repeat views atomically increment `view_count` and update `viewed_at`; anonymous views
still increment aggregate listing statistics but never create a user history row.

The history endpoint requires authentication instead of exposing the first database
user's history to anonymous callers.

## Devices and Preferences

`DeviceToken` gains:

- stable optional `device_id` (unique when present), generated per Flutter installation;
- `locale` (`ru` or `ky`);
- `timezone` (default `Asia/Bishkek`);
- a larger token field suitable for FCM refreshes.

Registration is authenticated and never accepts `user_id`. Upsert prefers `device_id`,
then token for backward compatibility. Re-registration moves the installation to the
current user and replaces its old token atomically. Canonical endpoints live at
`/api/v1/notifications/devices/` and `/api/v1/notifications/devices/current/`; existing
`/api/v1/devices/` routes remain as compatibility aliases.

Logout first deactivates the current installation while the access token is valid, then
revokes the refresh token and deletes the local FCM token. If backend unregister fails,
deleting the FCM token invalidates the old transport token; a later registration with the
same installation ID reassigns ownership safely.

Settings add `price_drop_viewed_enabled`. API exposes
`new_listing_match_enabled` as the canonical alias of the existing
`saved_filter_enabled`, while retaining the old field. In-app Notification creation is
unchanged when push preferences are disabled.

## Provider and Failure Handling

`PushProvider` is a small interface implemented by `FirebasePushProvider`. Provider
initialization is lazy and occurs only when `PUSH_ENABLED=true`. Disabled mode does not
read credentials or initialize Firebase.

Delivery groups devices by locale so RU and KY notification copy can differ. FCM data is
small and string-only: `notification_id`, `type`, and routing identifiers. New-message
previews are capped at 140 characters. Full tokens, private keys, and full private
messages are never logged.

Permanent invalid-token responses deactivate devices. Transient provider failures use
bounded Celery retry with backoff. Enqueue and provider failures never propagate into the
business request.

## Flutter

Flutter uses `firebase_core`, `firebase_messaging`, `flutter_local_notifications`,
`package_info_plus`, and the existing `shared_preferences`/`uuid` packages.

Firebase options come from `--dart-define` values. When the complete platform-specific
set is absent, `PushService` is disabled and the app behaves normally. No real
`google-services.json`, `GoogleService-Info.plist`, or service-account file is committed.

After authentication settles, the service requests notification permission once at a
meaningful session boundary, registers the FCM token, and listens to `onTokenRefresh`.
Foreground messages create one local notification on either the messages or price-alert
channel. Background system display is left to FCM, preventing duplicates.

`getInitialMessage` and `onMessageOpenedApp` feed one shared
`NotificationDestination` parser also used by the in-app notification page. A pending
destination waits for authentication and then opens the existing conversation or listing
route; unauthenticated cold starts retain the destination through the auth flow.

Android declares `POST_NOTIFICATIONS` and two channels. iOS declares background remote
notifications and a push entitlement; the owner must later enable APNs capability and
upload an APNs key in Firebase.

## Production Infrastructure

Baseline resource measurements:

- RAM total: 458 MB
- RAM available: 193 MB
- swap: 2047 MB total, 203 MB used
- Gunicorn RSS: 141 MB
- PostgreSQL RSS: 18 MB
- disk available: 2.2 GB

Redis uses the distro systemd service, binds only `127.0.0.1 ::1`, enables protected mode,
sets `maxmemory 32mb` with `noeviction`, and disables AOF/RDB persistence.

`house-push-worker.service` uses the existing environment file and runs:

```text
celery -A config worker -Q push --pool=solo --concurrency=1
  --without-gossip --without-mingle --without-heartbeat
```

The worker has `worker_prefetch_multiplier=1`, `Restart=on-failure`, a non-aggressive
restart delay, and bounded journal retention. A foreground smoke test precedes systemd
enablement. Active queues must report only `push`.

After Redis, after Celery, and again after 3–5 minutes idle, measure real RSS, available
RAM, swap, journal size, and kernel OOM messages. If available RAM is below 64 MB, idle
swap grows continuously, or HTTP/kernel health degrades, disable the worker and implement
the DB PushOutbox fallback instead. Gunicorn/PostgreSQL are never reduced for Celery.

## Deployment

Code is committed to Repo A and the backend subtree is mirrored into Repo B before any
production pull. Production must be clean and fast-forwardable. Before migration, record
the current HEAD and back up PostgreSQL plus `.env`. Then install tracked dependencies,
migrate, run Django checks, restart Gunicorn only because backend code/settings changed,
and verify API health.

Production remains at:

```text
PUSH_ENABLED=0
PUSH_PROVIDER=firebase
FIREBASE_PROJECT_ID=
FIREBASE_CREDENTIALS_FILE=/root/house-backend/secrets/firebase-service-account.json
```

The restricted `secrets/` directory is prepared, but no fake credential file is created.

## Verification

Backend tests cover device registration/reassignment/unregister, settings compatibility,
message enqueue, price-drop favorites/recent views/union/owner/stale/currency/idempotency,
disabled mode, task routing, provider failure/invalid token, localized payload, and the
test command. Flutter tests cover disabled configuration, token lifecycle orchestration,
destination parsing, and authenticated cold-start routing. Static analysis, Django check,
migration check, and a Flutter build/test complete local verification.

Production smoke proves a real Notification ID traverses the `push` queue and exits
disabled without Firebase initialization while the Notification row remains in PostgreSQL.
