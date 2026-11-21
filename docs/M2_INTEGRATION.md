# M2 integration and security gates

## Implemented on feature branches

- Website: GET /api/mobile/v1?kind=notes|updates|filters
- Flutter: HTTPS-only feed client, search, API-driven department/semester filters, Updates stream filters, pagination, loading/error/retry states, and scrollable published Update article body.
- Site API only returns public published metadata. It does not return R2 object keys, pre-signed reader URLs, student records, or credentials.
- Both codebases are kept on feature branches until tests and staging checks pass.

## Required environment

Flutter development command after a staging deployment:

flutter run -d linux --dart-define=SMIUNOTES_API_BASE=https://YOUR_STAGING_DEPLOYMENT

The URL must be an HTTPS deployment of the cyphernotes feature branch with the appropriate staging Supabase environment. Never use secret or service-role keys in a Flutter build. There is no default API URL: the app requires an explicit HTTPS staging URL. Without it, feeds show a recoverable error. Production is never used as a fallback.

## Before M2 acceptance

1. Run website lint, TypeScript, unit tests and production build.
2. Validate API 400 for invalid/duplicate filters and no-store response headers.
3. Validate RLS: only published notes and updates appear; private drafts and sensitive note pages never leak.
4. Verify staging site API against staging DB, including empty results and pagination.
5. Run Flutter analyze and tests via GitHub Actions and locally.
6. Confirm authenticated student OTP flow design: the existing student-auth function uses a server-only broker key. Never embed this key or a service-role key in the mobile binary.
7. Implement and verify short-lived mobile-safe session exchange, refresh, logout, student verification, and role-scoped access before enabling profile, community writes or sensitive note reader.
8. Render note pages with the same authorization decisions as the website. Reuse server-controlled manifest/page signing, never save or expose private R2 credentials.
9. A deployment to production needs separate explicit approval after staging and security review.

## Current limits

- Public lists and metadata only. No native private reader yet.
- Article detail and student login not connected.
- Community/Profile remain placeholders.
- No live integration or device build has been verified in this branch.
