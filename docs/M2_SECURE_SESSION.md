# M2 Secure Session — Implementation and Acceptance

**Status:** Code implemented on feature branches; live student login is still OFF. No production rollout.

## What is implemented

- `flutter_secure_storage: 11.1.1` provides an OS-backed, encrypted vault for a **single versioned** JSON credential record, rather than SharedPreferences or app files.
- `StudentSessionController` accepts a session only after a successful secure write. It refreshes before restoring a saved session; a stale/revoked session is erased on failure. Refresh-token rotation replaces both tokens; failed renewal clears local access.
- Sign-out calls the server's per-device revoke action and **always clears local tokens**, even if the server cannot confirm revoke. A failed server response is surfaced to the caller; it does **not** claim that all devices were signed out.
- `StudentSessionApi` calls the versioned HTTPS refresh/logout API. It never places tokens in URL query parameters.
- The Next.js session API validates requests, refreshes via Supabase Auth, re-checks `student_reader_profile` and Student Card verification, and calls `revoke_student_sessions` on logout. It is disabled unless `MOBILE_AUTH_ENABLED=true`.
- Mock vault tests cover atomic-save failure, restore with rotation, revoked token denial, refresh failure and logout network failure.

## Pending before activation

1. Provide an approved, device-accessible staging HTTPS hostname; the protected Vercel preview URL is not directly accessible from a mobile APK without an unsafe bypass.
2. Verify staging supports the production-equivalent `register_student_password_session` and `revoke_student_sessions` RPCs and account/verification grants. Do not switch development testing to production Supabase.
3. Integrate Turnstile via an approved user-verifiable challenge that produces a server-valid `mobile_login` proof. **Do not put Turnstile secrets in Flutter.**
4. Wire `MobileAuthApi`, `SecureSessionStore`, `StudentSessionApi`, `StudentSessionController` and `StudentProfileApi` into a tested lifecycle coordinator and interface; currently the login UI intentionally fails closed without security hooks.
5. Validate Android keystore and OS restore behavior; Linux builds require a functioning Secret Service/libsecret setup. Never use plaintext fallback if secure storage is unavailable.
6. Verify login, OTP, device limit, verified-only notes, Community moderation, token replay, refresh rotation, sign-out current/all devices, and account revocation on real Android hardware.
7. Run `flutter analyze`, `flutter test`, GitHub Android debug build, and end-to-end staging tests before merge.
8. Review `pubspec.lock` after running `flutter pub get` and commit dependency resolution before a release build. No secret should ever be placed in `--dart-define` or app source.

## QA note

The new Android debug APK workflow is **not proof of native login working**. It tests compilation/package assembly only, without a real student session. The produced APK remains a disabled-auth test build.

## Session coordinator and staged wiring

- `StudentSessionCoordinator` requires both a successful refresh and a server-fetched, active `StudentProfile` before treating restored credentials as authenticated.
- Suspended or unverifiable accounts cause local credential clearing. No cached JWT is used as a standalone permission grant.
- `StudentAuthRuntime.forStaging` composes the encrypted vault, refresh/revoke API and self-profile API without reading credentials or starting network access at construction time. It is intentionally **not connected to the default Profile tab** until mobile CAPTCHA/session lifecycle acceptance is complete.
- Mock tests cover successful validated restore, revoked profile denial, offline revoke cleanup and Profile logout clearance. These are unit tests, not a live session QA claim.
- Android debug builds have successfully run on earlier commits. The latest feature commit requires its own CI build confirmation.
