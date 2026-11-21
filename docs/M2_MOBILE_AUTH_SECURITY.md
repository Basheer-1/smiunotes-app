# SMIUNotes Mobile Authentication & Authorization — M2 Security Gate

Status: **design reviewed against existing repository code; implementation NOT enabled**.

## Existing trusted flow

- The Next.js student verification actions call Supabase Edge Function \`student-auth\` with \`STUDENT_BROKER_KEY\`, which must remain on the server.
- The Edge Function supports \`send\`, \`verify\`, and \`password\` and returns a Supabase access/refresh token pair only after challenge/password checks.
- The web actions call \`auth.setSession\` and, for password sign-in, \`register_student_password_session\`; reader access is further checked using \`student_reader_profile\`, \`student_verification_status\`, and \`can_read_sensitive_notes\`.
- The note-media function itself rechecks live verified status, session activity and staff permissions. Its \`manifest\` and \`page\` operations must never be bypassed.

## Recommended mobile approach (requires separate implementation and security review)

1. Implement a dedicated Next.js **mobile-session broker** rather than invoke \`student-auth\` directly from Flutter. Keep the broker key and any Supabase privileged key server-side.
2. Prefer short-lived, single-use, server-generated login challenges with rate limits/IP and device abuse controls. Registration, OTP recovery and device-limit rules must match the website. Do not expose the target email or student-directory eligibility to anonymous clients.
3. For password login, ensure a successful Supabase sign-in ALSO registers the session's device/grant using exactly the server-side rules used by the web flow. A password result alone is not a verified reader grant.
4. Obtain a Supabase session only through the verified server broker. Store refresh/access tokens in OS-backed secure storage, never SharedPreferences or source code. Never print access/refresh tokens, OTPs or passwords to logs.
5. Test refresh, app reinstall, sign out current/all devices, revoked sessions, expired OTP, reused challenges, and failed/locked accounts.
6. For authenticated note reads, use an authenticated mobile media broker that applies the existing live media authorization before signing pages. Sensitive note access must require approved Student Card verification, not simply login or contributor/admin role.
7. App should send credentials only to an approved HTTPS staging host, over server-validated requests. Vercel SSO/protection tokens, service-role keys and the broker key must never appear in the client binary.
8. Public Community/Updates/Notes metadata remains accessible without login, as the website allows. Posting/replying remains disabled until secure mobile session and RLS testing.
9. Validate CSRF strategy (if cookies), CORS, no-store, content/body size, abuse controls, session fixation, replay protection, and error privacy before any real-user rollout.
10. Ship only after isolated staging tests, an explicit production rollout decision, and a rollback plan.

## M2 acceptance matrix

| Scenario | Expected |
| --- | --- |
| Anonymous published non-sensitive note | manifest and signed WebP page |
| Anonymous draft note | 404, no signed URL |
| Anonymous sensitive note | 404, no signed URL |
| Authenticated unverified student | cannot read sensitive note or post |
| Approved verified student | limited authorized note/page and forum capabilities |
| Revoked/expired session | cannot sign page or post |
| OTP challenge replay | rejected |
| Oversized/malformed credentials | rejected with no sensitive detail |
| All-device signout | old token cannot regain reader rights |
| Production keys in APK | never |

These are design/acceptance requirements, not claims that the native login is already implemented.

## Implemented but OFF by default (November 21, 2026)

- A separate `POST /api/mobile/v1/auth` is present **only on the website feature branch**. It forwards validated Student ID password/OTP requests to the existing privileged broker, registers the same password session grant as web, and never sends a server secret to a client.
- Anonymous `password` and `send` calls require Cloudflare Turnstile proof verified server-side for the exact configured `MOBILE_AUTH_TURNSTILE_HOSTNAME` with action `mobile_login`. OTP `verify` uses the existing durable OTP attempt budget.
- The route refuses all login requests unless `MOBILE_AUTH_ENABLED=true`. Staging currently has not been enabled. `GET /api/mobile/v1/auth` reports the effective enabled status without returning secrets.
- The Flutter `MobileAuthApi` supports password, send and OTP verify request envelopes. It **does not yet connect to a login UI or persist tokens**, and must not handle real credentials until the CAPTCHA user flow, OS-backed encrypted storage, refresh/revocation and staging device tests are implemented.
- Current isolated staging schema was not confirmed to contain the production password-session registration and device-revocation RPCs. Additive staging migration/verification is required before enabling this broker; do not silently switch the endpoint to production Supabase.
- The app's existing Linux build must remain usable. Avoid introducing native plugins requiring libsecret/Android SDK until the local environment and package cache are prepared.

## Authenticated note-media adapter (feature-flagged)

- Website feature branch now contains `GET /api/mobile/v1/reader?op=manifest|page&id=<uuid>&page=<n>`. When disabled it fails closed with HTTP 503. Enabled requests require a valid Supabase bearer token, live `student_reader_profile` grant and the existing privileged `note-media` function for final Student Card authorization and short-lived WebP signing. It does not access R2 secrets itself.
- Flutter has `AuthenticatedReaderApi`, a token-scoped HTTPS client with strict note ID/page checks. Unit tests verify invalid tokens, invalid IDs, oversized pages and HTTP endpoints are rejected before network access.
- **Not connected to login UI and not deployed to production.** Native session persistence, refresh, revocation and verification-role tests still gate activation. Do not use unverified student credentials in staging.
- CI passed on website commit `f178bd82` and Flutter commit `ef419b79`. Live preview disabled-state check should be logged separately when deployed.

## Native login UI scaffold (current branch)

- `StudentLoginPage` includes Student ID/password, first-time email registration, OTP verification, new password entry, and a clear availability notice.
- The default `Profile` tab links to a login status preview. It **never** displays credential inputs unless all three conditions hold: mobile auth capability reports enabled, a trusted CAPTCHA callback is provided, and a secure session receiver is injected.
- No production CAPTCHA callback or secure session receiver is wired into the app. Therefore **real login is not yet available**. Do not ask students to enter real credentials into this build.
- `test/student_login_test.dart` checks the disabled server case and the server-enabled-but-missing-secure-hooks case. These checks guard against accidental credential collection.
- Before enabling, integrate verified Turnstile proof generation, OS-backed encrypted session persistence and refresh/revocation, then rerun device-level session and verified-card checks.

## Mobile account recovery and staging grants (November 21, 2026)

- The website mobile auth broker now supports an optional `recover` request protected by the same server-verified Turnstile challenge and existing `student-auth` recovery RPC. It deliberately returns generic eligibility information and never changes account ownership or recovery email directly.
- The Flutter `MobileAuthApi.requestRecovery` client and guarded `StudentRecoveryPage` permit a recovery request only when server capability is enabled and a trusted challenge callback supplies proof. The default app still does not activate these credentials screens.
- Synthetic widget tests verify the recovery UI is hidden when disabled, successful mock submission, and denial when CAPTCHA proof is missing.
- **Staging database inspection** confirmed `revoke_student_sessions`, `account_profile`, `student_verification_status`, and `student_reader_profile`, but `register_student_password_session` was **absent**. No migration was applied. Before activation, additively migrate the correct, reviewed device-grant RPC and verify it matches production rules.
- A new server-only readiness variable, `MOBILE_AUTH_GRANTS_VERIFIED=true`, is required in addition to the original mobile auth, Turnstile, broker and OTP gates. Do not set it until database parity and device-limit tests actually pass. The gate remains off in all current staging tests.
