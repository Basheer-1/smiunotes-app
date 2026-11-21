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
