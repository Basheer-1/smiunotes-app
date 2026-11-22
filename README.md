# SMIUNotes — Flutter Mobile App

> Native mobile companion to [SMIUNotes](https://smiunotes.com), an independent student-run resource for SMIU. **Not an official university application.**
>
> **Website/backend repository:** [Basheer-1/cyphernotes](https://github.com/Basheer-1/cyphernotes) · **App package:** `com.smiunotes.app` · **Documentation review:** 22 November 2026.

## Maintainer handover: read this first

The mobile app is a **separate Flutter/Dart client of the same SMIUNotes ecosystem**. It does not have a separate authoritative student/notes database: web services expose a versioned HTTPS API, and changes must remain compatible with the website. This document describes the checked repository structure and operational safeguards, **not a claim that every feature flag is enabled or every installed APK contains the latest commit**.

If you are taking over:

1. Read this README **and the [website README](https://github.com/Basheer-1/cyphernotes#readme)**; request scoped GitHub, test API and Android signing/CI access only as required.
2. Install a Flutter SDK supporting Dart `^3.14.0`, Android SDK/toolchain and JDK 17; check `flutter doctor -v`.
3. Read `lib/main.dart`, `lib/services/`, `lib/screens/`, `android/app/build.gradle.kts` and existing tests.
4. Run the test suite and start an **unprivileged, nonproduction** build. Validate feeds before enabling accounts, push or release signing.
5. For every modification to login, notes, updates, community or profile, inspect the matching `/api/mobile/v1/*` implementation in the website repository.

## What it does

The app provides a native Material-based shell with **Home, Notes, Updates, Community, Profile** navigation. It includes public content feeds, catalogue/filter/search UI, note reading, community threads, student profiles, authentication/verification flows, study bookmarks, support/contact forms, notification inbox and preference controls. A screen or service existing in code does **not** guarantee it is available in an ordinary production build; some flows require compile-time flags and live backend endpoints.

| Concern | Implementation |
| --- | --- |
| UI | Flutter / Dart, Material 3; `material_ui` package |
| Theme | Archive Blue palette, light/dark mode, secure preference storage |
| Typography | Bundled **Inter** and **Space Grotesk** to match the website |
| HTTPS integration | Dedicated Dart APIs under `lib/services/`, primarily `/api/mobile/v1/*` |
| Sessions | Student auth runtime, coordinator and `flutter_secure_storage` |
| Notes / updates | Public feed + native reader with filtered server data |
| Push delivery | Android Firebase Cloud Messaging dependency; backend accounts/notification records remain in Supabase |
| Android | Package `com.smiunotes.app`, Gradle, JDK 17, separately supplied release keystore |

At README review time, `pubspec.yaml` advertises version **`1.0.1+2`** and SDK **`^3.14.0`**; always verify these values again at release time. The checked direct dependencies include `material_ui`, `flutter_secure_storage`, `webview_flutter`, `cupertino_icons`, `flutter_test` and `flutter_lints`.

## Architecture and navigation

```text
Flutter AppShell (lib/main.dart)
  |-- Home / Notes / Updates / Community / Profile
  |-- lib/screens/      native views and flows
  |-- lib/widgets/      reusable visual components
  |-- lib/models/       typed data / profile models
  |-- lib/services/     HTTP, auth, bookmarks, preferences, verification, media
          |
          v
  HTTPS /api/mobile/v1/* on the SMIUNotes website
          |
          v
  Website server authorization -> Supabase Auth/PostgreSQL/RLS
                                -> private media / R2 integration
  Firebase Messaging -> Android push transport (when configured/enabled)
```

Useful entry points:

| File | Start here for |
| --- | --- |
| `lib/main.dart` | App bootstrap, bottom navigation, themes, feature flags, tab/refresh behavior |
| `lib/screens/public_feed_page.dart` | Notes/updates feeds, search, filters, pagination, pull-to-refresh, resume refresh |
| `lib/screens/community_feed_page.dart` | Public discussion list and detail navigation |
| `lib/screens/staging_student_account_page.dart` | Student account coordinator, profile, verification, preferences, push enrollment; filename reflects its historical origin |
| `lib/services/public_feed_api.dart` | Published content transport |
| `lib/services/mobile_auth_api.dart`, `lib/services/student_auth_runtime.dart` | Session/auth orchestration |
| `lib/services/native_student_forms_api.dart` | Contact, verification, support requests, HTTPS and payload validation |
| `lib/services/push_registration_api.dart` | Push registration service |
| `android/app/build.gradle.kts` | Android app identity, release signing and Firebase Messaging dependency |
| `test/` | Flutter regression tests; enumerate current tests rather than assuming all flows are covered |

Security boundary: mobile UI is **not** a trusted server. The backend must validate student identity, verification status, role, record ownership, deadline state, token and media access on every protected operation. Do not embed Supabase service keys, R2 credentials, signing keys or backend bypass tokens in Dart or Android resources.

## Configure a developer machine

```bash
git clone https://github.com/Basheer-1/smiunotes-app.git
cd smiunotes-app
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter run
```

An emulator or connected Android device is required for `flutter run`. Use the Flutter toolchain that meets the checked Dart SDK constraint. On Linux, ensure Android SDK licenses and Java are correctly configured.

### Compile-time options (important)

`lib/main.dart` reads these `--dart-define` variables:

| Name | Purpose |
| --- | --- |
| `SMIUNOTES_API_BASE` | Trusted HTTPS website API origin; omit trailing paths/query strings |
| `SMIUNOTES_ENABLE_STAGING_AUTH` | Enables historical staging account flow |
| `SMIUNOTES_ENABLE_PRODUCTION_AUTH` | Enables authorized production account flow |
| `SMIUNOTES_ENABLE_NATIVE_PUSH` | Native push registration/enrollment switch (checked in the account screen) |

These are compile-time configuration switches, not secrets and not proof that a backend feature is deployed. A default `flutter run` may have account features disabled. For an **approved test backend only**, an example command is:

```bash
flutter run \
  --dart-define=SMIUNOTES_API_BASE=https://YOUR-TEST-API-ORIGIN.example \
  --dart-define=SMIUNOTES_ENABLE_STAGING_AUTH=true
```

Do not use the owner's live API for destructive registration, payment or moderation tests. Only enable native push after the backend registration, device rotation/revocation, Firebase configuration and device acceptance are tested. `google-services`/Firebase configuration may be required by the Android build; obtain it through approved project settings, not a copied private service-account key.

## Shared website/API contract

The website and the app must stay synchronized by **backend truth and compatible APIs**, not by copying page source or duplicating databases.

- **Public feeds:** read published notes, updates, catalogue filters and community from server responses. UI must show loading, empty and error states.
- **Refresh:** `PublicFeedPage` contains a `RefreshIndicator`, refreshes on app resume and reacts to shell tab refresh versions. Confirm a newly published note/update appears without restarting the app.
- **Updates:** use the server's authoritative time/deadline and published visibility. Apply actions must not be available after expiry; status labels (upcoming/active/expired) should match the website.
- **Auth:** secure session storage, refresh/revocation, email/Student ID verification, account state and server-enforced access. An expired token should lead to safe reauthentication.
- **Community and bookmarks:** posting/saving requires appropriate authentication and verification; public reading can remain independent.
- **Media:** note originals remain private; only allow authorized reader/media access, respecting short-lived URLs.
- **Forms:** `NativeStudentFormsApi` requires an HTTPS origin, validates input sizes and sends bearer auth for protected operations. An endpoint may be unavailable; never silently treat HTTP errors as success.
- **Errors:** parse bounded server responses and handle offline/timeout, 401/403, validation and retry distinctly where possible.

**When changing an API:** document URL, method, authentication, request/response schema, status/error formats, pagination, visibility, caching and backward compatibility. Add matching tests in **both** repos. Prefer additive changes; coordinate the website deployment before distributing an app that requires a new endpoint.

## Run checks and test a release candidate

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

If the repository's existing formatting baseline differs, record that separately rather than mass-reformatting an unrelated change. For release QA, test on at least one physical Android device plus an emulator as available. Check: initial launch, navigation, both themes, login/logout/expired sessions, student verification, profile/avatar, notes and WebP reader, newly published feed refresh, update statuses/apply deadlines, forum posting constraints, bookmarking, offline retry, slow network, notifications, permissions and accessibility. Confirm server-side enforcement using a low-privilege test account; never test admin restrictions with real student data.

## Android build and signing (read before shipping)

`android/app/build.gradle.kts` **intentionally refuses to substitute debug signing for a release**. A signed release needs all four environment variables:

```bash
export SMIUNOTES_RELEASE_KEYSTORE=/absolute/path/to/upload-keystore.jks
export SMIUNOTES_RELEASE_STORE_PASSWORD='...'
export SMIUNOTES_RELEASE_KEY_ALIAS='...'
export SMIUNOTES_RELEASE_KEY_PASSWORD='...'
flutter build appbundle --release \
  --dart-define=SMIUNOTES_API_BASE=https://smiunotes.com \
  --dart-define=SMIUNOTES_ENABLE_PRODUCTION_AUTH=true
```

The commands illustrate the configuration shape; **do not execute or distribute a production build until the owner verifies backend readiness and explicitly approves which flags to enable**. Never check a keystore or passwords into Git, send them in chat, or replace the existing upload key casually. Confirm the actual app ID, versionCode/versionName, Firebase app registration, Android manifest, Play Console signing policy and distribution method before publishing. Increment the `version:` in `pubspec.yaml` for an intended update. An APK built before a commit will not change because GitHub changes: it must be **rebuilt, signed and installed/distributed**. Maintain a release log with commit SHA, version, enabled flags and artifact checksum.

## Deploy and rollback

1. Make a feature branch and PR; document visual/API/permission changes and tests.
2. Verify `flutter analyze`/`flutter test` and a clean device installation, including the backend contract.
3. Coordinate server changes with the website maintainer: backward-compatible API first, app release second.
4. Build a **new**, correctly signed release artifact with intended `--dart-define` flags; test that actual artifact on a device.
5. Publish only after owner sign-off. For regressions, use a previously approved build (subject to Android version and store rules); for backend faults, roll back compatible server code **without blindly reverting database migrations**.

The app is not a staging environment for the live database. Keep development, preview and production endpoints and Firebase registrations clearly separated. A web-only deployment does not rebuild users' installed apps.

## Learning curve: from beginner to app maintainer

| Stage | What to learn | Prove you understand it by… |
| --- | --- | --- |
| 0 — Tools | Git, Linux terminal, Android Studio/SDK, Flutter CLI, debugging | Run the app on your device and inspect logs |
| 1 — Dart | Null safety, classes, futures, async/await, exceptions, collections | Parse typed mock API data |
| 2 — Flutter | Widgets, layout, navigation, lifecycle, themes, state | Modify a native card and handle loading/error states |
| 3 — Network | HTTP/JSON, pagination, auth headers, timeouts, REST contracts | Trace one note from Dart API to Next.js endpoint |
| 4 — Authentication | Session/token lifecycle, secure storage, verification, authorization | Explain why a UI-auth check is insufficient |
| 5 — Features | Feeds, search/filters, reader, forms, refresh and deadline status | Add a test-driven update-field change to both clients |
| 6 — Testing | `flutter_test`, mocks/fakes, integration QA, offline/device behavior | Catch a stale feed or expired Apply regression |
| 7 — Android release | Gradle, Firebase/FCM, signing, flavors/defines, versioning | Deliver a signed test build with a reproducible release note |
| 8 — Ownership | Monitoring, rollback, backend coordination, security/privacy | Review a full cross-repo PR and its rollback plan |

Suggested learning sequence: **4–8 weeks** for Dart/Flutter basics plus **2–4 weeks** practicing this repository, adjustable to experience. Start with UI/feed tests; leave authentication, payment/verification, push credentials and signing to reviewed changes.

## Contributor standards and handover checklist

Use small PRs; never push directly over another developer's work. State **expected behavior, affected screens, API endpoints, evidence of tests, screenshots, feature flags and APK rebuild requirement**. Preserve the design system (Archive Blue, glass/transparency where appropriate, bundled fonts), accessibility and familiar bottom navigation. Handle privacy carefully: never log auth tokens, student IDs with personal details, student-card images, receipts or private signed URLs.

Before accepting project ownership, verify: access to both repos, secrets ownership/rotation policy, separated environments, backend deploy order, latest functional APK and signing custody, Firebase configuration, CI/QA procedure, release/version history, store listing (if any), and an incident rollback contact. Missing access or unknown deploy state should be explicitly recorded—not guessed.

**See also:** [Website README and full-stack roadmap](https://github.com/Basheer-1/cyphernotes#readme). Update both READMEs whenever shared API behavior, permissions, configuration or deployment requirements change.
