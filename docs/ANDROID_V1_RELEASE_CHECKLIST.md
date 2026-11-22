# SMIUNotes Android 1.0 — release acceptance

## Candidate and safety boundary
- Package: `com.smiunotes.app`; Flutter version: `1.0.0+1`.
- Production API origin: `https://smiunotes.com`.
- Native student sign-in, profile, notes, updates and community may be enabled only after acceptance.
- Push delivery must remain **off** until actual device and background-delivery testing passes. Never set `SMIUNOTES_RELEASE_PUSH_ACCEPTED=approved` without evidence.
- Existing debug tester APKs are not production-signed; never distribute them as the v1.0 release.

## Required real-device acceptance
- [ ] Fresh install and upgrade path; stable launch and bottom navbar; light/dark mode, small screens, and accessibility text size.
- [ ] Student ID/password login; first-time registration with email OTP; recovery; logout; revoked-session restore; Cloudflare challenge.
- [ ] Guest support methods and voluntary receipt form; authenticated verified student support; proof upload and duplicate-claim handling; admin bank-credit review **using test transactions only**.
- [ ] Profile photo change/remove; account info and verification state; change password using current password; device rename and revoke; sign out all; verify each state persists on website.
- [ ] Pending Student Card verification and provisional deadline; upload and administrative decision with test identities only.
- [ ] Notes browse/reader/bookmarks/completed library; Updates; guest Community read; Reply login modal; verified composer.
- [ ] Notification preference updates persist on website; essential alerts cannot be switched off.
- [ ] If push is in scope: FCM opt-in, Android runtime permission, foreground/background/terminated notification, token revocation and delivery. Otherwise keep native push disabled.
- [ ] Verify own-account RLS: no cross-account profile, receipt, photo or device access.
- [ ] No crash or data leak when offline, on timeout, malformed response, expired token or revoked access.

## Release gate and signing
1. Resolve GitHub PR conflicts and pass current Flutter analyzer, widget tests, Android CI, and production API preflight.
2. Confirm the release keystore is stored only as protected `android-release` Environment secrets: `SMIUNOTES_RELEASE_KEYSTORE_BASE64`, `SMIUNOTES_RELEASE_STORE_PASSWORD`, `SMIUNOTES_RELEASE_KEY_ALIAS`, `SMIUNOTES_RELEASE_KEY_PASSWORD`. Keep an offline backup; never commit keystore or passwords.
3. Record approved values in the protected environment only after device evidence: `SMIUNOTES_RELEASE_API_BASE=https://smiunotes.com`, `SMIUNOTES_RELEASE_AUTH_ACCEPTED=approved`, `SMIUNOTES_RELEASE_PUSH_ACCEPTED=approved` **only if push was actually tested**.
4. Manually run `Android Signed Release Candidate` from `main` using `RELEASE_APPROVED` and reviewer approval. It generates a signed **AAB**, not a debug APK.
5. Verify AAB signing fingerprint/package identity and version code, use internal testing before wider release, and prepare privacy policy, Data Safety and store listing. Never publish without final approval.

## Current caveat
The authenticated payment/photo/card submission routes are deployed, but automated endpoint readiness and Dart widget tests **do not establish** end-to-end financial/identity acceptance. This checklist remains authoritative until those device cases pass.
