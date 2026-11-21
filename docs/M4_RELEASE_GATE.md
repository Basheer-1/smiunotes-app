# M4 — Notifications and final release readiness

## Phase 1
- Header bell opens a local notification page; unauthenticated state makes no network request.
- Typed own-account notification model, read-only list, loading/error/retry and widget tests.
- Website already has member inbox and browser Web Push; Android native push is separate.
- No native mobile inbox endpoint, push permission or FCM delivery has been enabled yet.
- Backend hrefs must be allowlisted before native navigation. New-note alerts stay disabled.

## Phase 2 — staged integration (not activated in default builds)
- Website feature PR #95 adds a bearer-authenticated `/api/mobile/v1/notifications` API backed by existing own-account Postgres notification RPCs. No new tables or production schema changes.
- Flutter `MobileNotificationApi` uses explicit HTTPS base URL, validates tokens and response shapes, and supports list, read and clear.
- In the staging account gateway, the inbox is available only after a live verified session. Default app bell remains a network-free guest preview.
- New-note broadcasts remain disabled. No Firebase credentials, Android runtime notification permissions or production service endpoints have been embedded.
- Backend PR #95: https://github.com/Basheer-1/cyphernotes/pull/95 (draft). Flutter PR #4 remains draft.

## Outstanding acceptance
- [ ] Device-accessible HTTPS staging without an embedded Vercel protection token.
- [x] Protected mobile inbox endpoint written on isolated website branch; staging revocation and cross-user negative-path verification pending.
- [x] Wire staged verified Flutter session to inbox read, mark-read and clear API callbacks; real backend acceptance pending.
- [ ] Opt-in native Android push and per-device unregister.
- [ ] Real-device Turnstile, four-device sessions, revoke, note/community permissions.
- [ ] Secure-store, signed-page cache, OS notifications and distribution QA.
- [x] Debug-key fallback removed from Android release build. Production keystore, non-example application ID, release AAB, and signed-install QA remain pending.
- [ ] Separate production merge/deployment approval.

M4 branch is isolated from production, main, frozen M2/M3, and Kamil staging.

## Android release signing (not yet provisioned)
- Android `release` no longer inherits Flutter's debug signing config. A production store is NOT configured and no signed store-ready AAB has been generated.
- Provide `SMIUNOTES_RELEASE_KEYSTORE` (path to private upload keystore), `SMIUNOTES_RELEASE_STORE_PASSWORD`, `SMIUNOTES_RELEASE_KEY_ALIAS`, `SMIUNOTES_RELEASE_KEY_PASSWORD` **only** as secured environment variables in an approved release environment.
- Never commit the keystore or passwords, including inside GitHub Actions logs, artifacts, or source. Back up the original key securely.
- Finalize unique Android `applicationId` and signing ownership before first Play Store upload. Current `com.example.smiunotes_mobile` is a placeholder, not approved for release.
- Do not run or distribute a release build while credentials are missing; an unsigned release artifact is not publishable.
