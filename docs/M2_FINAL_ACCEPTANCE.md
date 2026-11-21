# SMIUNotes Flutter M2 — final acceptance gate

This is a **testing checklist**, not a declaration that M2 is fully released.

## Implemented and automated

- Public Notes, available-only catalogue filters, Updates and Community with full public discussion/replies.
- Public WebP viewer uses live published note manifests and 60-second signed URLs; private draft access is denied server-side.
- Secure student password/OTP/recovery broker behind Turnstile and server-only keys; authorization and account status are checked on server.
- Session credentials stored only in an OS-backed secure vault. Restore refreshes first, checks own-account status, and clears stale sessions. Per-device logout uses website revoke endpoint.
- Native Cloudflare Turnstile WebView component and first-party challenge page exist, but a real device/approved origin test is still required.
- Authenticated WebP reader UI + API signs individual pages through existing note-media authorization; staging Profile has a QA-only UUID opener, never guest-facing.
- Community POST adapter uses existing `forum_post` DB RPC with rate limits, restrictions and locks; staging-only authenticated composer.
- Staging SQL migration `20261119100000_student_password_login.sql` applied; grant and EXECUTE privileges verified. No production changes.
- Synthetic widget tests cover login capability, recovery, active account, refresh/logout, and reader missing authorization.
- Pin package versions in `pubspec.lock`. GitHub Flutter CI checks the lockfile is unchanged after `flutter pub get`.

## Release blockers — do not enable login yet

1. **Device-accessible staging HTTPS endpoint**: the existing Vercel staging preview uses Deployment Protection and cannot safely be embedded in APK with a bypass token. Preserve protection until a separate approved staging access approach exists.
2. **Cloudflare Turnstile**: configure a staging sitekey, secret and hostname. Test actual WebView widget and server Siteverify action `mobile_login`, including expiry, replay and failed challenge. Do not place the secret in the APK.
3. **Backend readiness flag**: `MOBILE_AUTH_GRANTS_VERIFIED` must remain false until staging password device grant, max-four active Auth sessions, revoke-on-other-device, and stale JWT denial are verified. Keep `MOBILE_AUTH_ENABLED` false until ALL checks pass.
4. **Actual Android security**: install debug APK on physical device, verify Android keystore save/restart/refresh, logout, reinstall, locked accounts, OTP expiry, no plaintext tokens or logs, and that screenshot/clipboard behavior meets product expectations. Native WebP images may be retained in memory/cache and screenshot protection is not guaranteed yet.
5. **Protected notes**: test verified Student Card works and anonymous, provisional/unverified, rejected, revoked, draft and expired sessions never receive protected signed URLs; test refresh of 60-second page URLs.
6. **Community writes**: test verified-only posting/replies, locks/bans/timeout, rate limits and revoked session denial; do not rely solely on synthetic widget tests.
7. **Android release compile**: newest debug build must be green (Gradle dependency server has sometimes responded HTTP 429). A passing Flutter analysis is not an APK success.
8. **Security review**: avoid direct privileged Supabase calls from Flutter, review WebView navigation and JS bridge, validate sensitive media handling, and check Supabase Security Advisor notices.

## Operational safeguards

- App feature build switch is **off by default**: `SMIUNOTES_ENABLE_STAGING_AUTH=false`.
- Production app, website branch `main`, and the tester's `kamil-staging` branch are NOT touched by this M2 draft.
- No production deploy or student credential testing until all blockers are checked.
- Never distribute a debug APK configured with production credentials or a Vercel protection bypass.
