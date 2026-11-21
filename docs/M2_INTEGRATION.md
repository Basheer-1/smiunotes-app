# M2 integration and security gates

## Implemented on feature branches

- Website: GET /api/mobile/v1?kind=notes|updates|filters|community|thread|manifest
- Flutter: HTTPS-only client, API-driven department/semester/subject filters, Updates and Community search, pagination, full published Update article body, public note manifests and on-demand signed WebP page reader.
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
6. Test public WebP notes end-to-end, including 60-second URL expiry, retry, page budget, invalid IDs, and verified-only denial. Confirm authenticated student OTP flow design: the existing student-auth function uses a server-only broker key. Never embed this key or a service-role key in the mobile binary.
7. Implement and verify short-lived mobile-safe session exchange, refresh, logout, student verification, and role-scoped access before enabling profile, community writes or sensitive note reader.
8. Render note pages with the same authorization decisions as the website. Reuse server-controlled manifest/page signing, never save or expose private R2 credentials.
9. A deployment to production needs separate explicit approval after staging and security review.

## Current limits

- Public note reader now implemented on feature branch but not yet staging-tested. Verified-only notes remain locked until native authentication is built.
- Published Updates article detail and public Community summaries and full public thread/replies details are wired in code. Student login is not connected.
- Community public reading is implemented; posting/replies and authenticated Profile remain pending.
- No live integration or device build has been verified in this branch.

## Preview protection and device testing

The isolated Vercel preview may enforce Vercel Authentication/SSO. A temporary share link used for automated server-side verification is **not** a permanent mobile API endpoint. Never hardcode a Vercel protection-bypass secret, private share link, or server secret into the APK. Keep the API base unset until there is an approved device-accessible staging endpoint. Mobile integration tests with fake API clients can run now; live device tests require an explicitly permitted HTTPS staging URL.

## Verified Community detail behavior

- New public read-only `kind=thread&id=<uuid>&page=<n>` uses the existing `forum_thread` RPC on a scoped anonymous Supabase client. Archived/hidden discussion and malformed or missing IDs are not exposed.
- Public Flutter Community cards open a full thread and visible replies page with pagination; a fake API test covers feed-to-thread navigation.
- Staging preview returned HTTP 400 for malformed ID/page, HTTP 404 for nonexistent thread and HTTP 200 for public community list. There is currently no public staging discussion, so successful thread/replies positive-path live verification remains pending.
