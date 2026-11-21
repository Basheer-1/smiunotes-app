# M4 — Notifications and final release readiness

## Phase 1
- Header bell opens a local notification page; unauthenticated state makes no network request.
- Typed own-account notification model, read-only list, loading/error/retry and widget tests.
- Website already has member inbox and browser Web Push; Android native push is separate.
- No native mobile inbox endpoint, push permission or FCM delivery has been enabled yet.
- Backend hrefs must be allowlisted before native navigation. New-note alerts stay disabled.

## Outstanding acceptance
- [ ] Device-accessible HTTPS staging without an embedded Vercel protection token.
- [ ] Protected mobile inbox endpoint with revoked-session and per-user checks.
- [ ] Connect verified native session to inbox read, mark-read and clear APIs.
- [ ] Opt-in native Android push and per-device unregister.
- [ ] Real-device Turnstile, four-device sessions, revoke, note/community permissions.
- [ ] Secure-store, signed-page cache, OS notifications, release signing and distribution QA.
- [ ] Separate production merge/deployment approval.

M4 branch is isolated from production, main, frozen M2/M3, and Kamil staging.
