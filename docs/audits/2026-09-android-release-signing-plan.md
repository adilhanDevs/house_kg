# Android release signing — migration plan (not executed)

Status per audit: **MUST FIX BEFORE PUBLIC DISTRIBUTION.** No change made in
this pass — generating a real signing key is a long-term release asset that
needs explicit owner approval, not something to create as a side effect of
an audit.

## Current state (confirmed)

- `flutter_app/android/app/build.gradle.kts`: `applicationId =
  "kg.housekgz.house_kgz"`, `namespace = "kg.housekgz.house_kgz"`.
- `release` build type: `signingConfig = signingConfigs.getByName("debug")`
  — every release build, including any already distributed via the private
  `adilhanDevs/house-kg-builds` GitHub Release, is signed with the debug
  keystore.
- Debug keystore fingerprint (this machine's `~/.android/debug.keystore`,
  alias `androiddebugkey`):
  - SHA1: `B7:54:C2:ED:30:2E:71:F9:38:45:24:27:5E:FC:7E:F8:F2:21:D5:2B`
  - SHA256: `B9:D3:8B:4E:9E:68:E2:4E:AC:93:93:14:89:DD:4F:00:F8:8F:B9:B9:FF:A5:9A:DA:0C:C3:F1:41:65:A2:BD:3E`
  - This is the *auto-generated, machine-local* debug key (not committed to
    git) — every developer's machine has a different one. This matters
    because it means **APKs built on different machines are not
    mutually upgrade-compatible** (Android rejects an update signed by a
    different key than the installed app) — a second, independent reason
    beyond tamper-detection to move off it before wider distribution.
- No `key.properties` or `*.keystore`/`*.jks` file exists in the repo
  (correctly gitignored per `android/.gitignore` if one is ever added).

## Why this matters (concretely, not just "best practice")

1. **Tamper detection**: anyone can re-sign an APK with their own debug key
   and redistribute it as if it were legitimate — nothing on the receiving
   device flags this, since debug keys aren't tied to a verified identity.
2. **Play Store hard requirement**: the Play Console rejects debug-signed
   uploads outright; this blocks Play Store distribution entirely, not just
   a "should fix."
3. **Upgrade continuity**: once *any* real users install a debug-signed
   build, switching to a real release key later means those users cannot
   upgrade in place — Android treats it as a different app (different
   signer). The earlier this migration happens, the smaller that blast
   radius. Confirm current distribution scope (private GitHub Release,
   closed testing) before deciding how urgent this is *right now* vs.
   before the *next* public-facing distribution.

## Migration steps (for the owner to execute, not this session)

1. **Generate the release keystore** (interactive, owner-run — this session
   will not generate it without separate explicit approval, since a signing
   key is a long-lived credential, not a disposable config value):
   ```bash
   keytool -genkey -v -keystore house-kgz-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias house-kgz
   ```
   Store the resulting `.jks` and its passwords in a password manager / secret
   store — **not** in the repo, not in chat, not in a shell history file.
2. **Add `key.properties`** (gitignored, same pattern Flutter's own template
   uses) with `storePassword`, `keyPassword`, `keyAlias`, `storeFile`.
3. **Wire `build.gradle.kts`** to read `key.properties` and define a
   `release` `signingConfigs` entry using it, replacing
   `signingConfigs.getByName("debug")` in the `release` build type.
4. **Record the new release cert's SHA1/SHA256** (same `keytool -list -v`
   command as above) somewhere durable (this doc, or a secrets manager note)
   — Play Console and Firebase both need this fingerprint registered
   separately.
5. **Rebuild and verify**: `flutter build apk --release`, then
   `apksigner verify --print-certs` to confirm the new cert is actually
   applied (not silently still the debug one via a Gradle config typo).
6. If any build has *already* been distributed to real users before this
   migration, they will need to **uninstall and reinstall** (not update in
   place) once the signing key changes — plan that communication before
   flipping the switch, not after.

## Explicitly not done in this pass

- No keystore generated.
- No `build.gradle.kts` change.
- No Play Console / Firebase app registration touched.
