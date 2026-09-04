# Android FCM takeover

Goal: complete the supplied takeover specification without replacing the existing outbox or changing secrets. Execute inline; preserve existing worktrees.

- [x] Recover both repositories and verify the production host.
- [x] Verify ignored Android configuration and credential provenance. Downloads key belongs to another project; production credential installation is blocked.
- [x] Test and implement a platform-independent push coordinator: authenticated token lifecycle, serialized registration/logout, persistent permission prompt state in Android adapter, pending recipient-bound navigation and deduplication.
- [x] Integrate Firebase adapter in main and AppScope, existing API methods and notification refresh UI; add modern Kotlin DSL Google Services plugin.
- [x] Add recipient_id to existing backend payload in both repositories with focused contract tests; run existing device/outbox tests on PostgreSQL.
- [x] Run analyzer, focused Flutter tests, backend checks, and ARM64 release build. Verify package/version/signature.
- [x] Commit tested implementation; push/deploy Repo B 6128636, keep PUSH_ENABLED=0, verify health. Monorepo documentation/release metadata follows.
- [x] Publish APK only to verified private prerelease repository (v2110) and provide honest report and physical-phone checklist in docs/FCM_ANDROID_RUNBOOK.md. Physical receipt awaits the owner and fresh matching Admin key.

Client design: PushCoordinator owns session generation, token work queue, retry on resume, pending intent and seen notification IDs. FirebasePushMessaging owns Android plugin calls and streams. AppScope owns NavigatorState key and waits until a non-startup route is ready; existing pages remain destinations. AppState exposes a pre-logout hook and notification revision. No Firebase network in ordinary unit tests.

Backend change: _data_payload adds string recipient_id from Notification.user_id (never caller-supplied payload). Tests require authoritative recipient and bounded string payloads. Port the exact semantic change to Repo B, never its unrelated settings changes.
