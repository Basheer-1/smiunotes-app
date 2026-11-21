# SMIUNotes Flutter — M3 content integration freeze

**Status: Code review complete, automated CI required before declaring frozen.**
**Scope:** Notes catalogue / public signed-page reader, Updates detail, public Community list/thread, read-only Profile. M2 authentication and backend grants remain off on staging.

## M3 acceptance matrix (automated)
- [x] Notes catalogue forwards the configured API client to the reader.
- [x] Async Notes, Updates, Community responses cannot overwrite more recent filter/query results.
- [x] Switching public feed kind or client resets old filters and search query.
- [x] Dependent department -> semester -> subject dropdowns reset previous form values.
- [x] Client search fields cap input at 100 characters, matching the website read API.
- [x] Public note identity/client change invalidates manifest and signed page URL state.
- [x] Community thread identity/client change reloads current discussion and replies.
- [x] Update article body and existing category, event and deadline metadata are shown.
- [x] Non-active student account details are hidden from standalone Profile.
- [x] Widget regression tests cover above interactions.
- [ ] **Final commit:** Flutter analyze, pubspec.lock validation, flutter test all green; see M3 draft PR for latest run.
- [ ] **Final build:** Android debug APK built for final commit. Not equal to device QA.

## Explicitly deferred to final real-device/security acceptance
- Staging Turnstile sitekey/secret, first-party Android access without a baked-in Vercel protection bypass; feature flags remain off until approved.
- Real verified/unverified student login, four-device session rotation/revocation, private signed pages, verified Community writes, Android Keystore/cache and screenshot behavior.
- Android device installation, staging connectivity, production release signing, push notifications, release deployment.

## Isolation
All M3 work is on `feat/m3-content-experience`; PR #3 is draft against frozen M2 branch `feat/m2-public-feeds`. No production/main merge, no modification to Kamil staging, no production student credentials or private assets. Release readiness and M3 code completion are separate gates.
