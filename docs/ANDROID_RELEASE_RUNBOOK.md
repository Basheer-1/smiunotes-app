# SMIUNotes Android — controlled production release runbook

## Current release state
- M4 default debug APK is a preview build, without a configured HTTPS API and without native FCM push.
- Production signing and Play submission are not ready yet. Do not distribute a release as production until the gates below pass.
- The workflow `.github/workflows/android-signed-release.yml` can ONLY be started manually; it requires a protected GitHub Environment named `android-release`.
- App applicationId is currently `com.example.smiunotes_mobile`; choose the permanent unique Android package name before release.

## Operator setup (never send credentials to ChatGPT or commit them)
1. In GitHub Settings > Environments, create `android-release` and require manual reviewers.
2. Use an approved release upload key and store the private key and passwords in a secure password manager with backups.
3. Configure the `SMIUNOTES_RELEASE_API_BASE` environment variable to `https://smiunotes.com` **only after** the public production mobile API passes acceptance. A website homepage is not proof of API readiness. Configure environment secrets:
   - `SMIUNOTES_RELEASE_KEYSTORE_BASE64`: base64 of upload keystore JKS file
   - `SMIUNOTES_RELEASE_STORE_PASSWORD`
   - `SMIUNOTES_RELEASE_KEY_ALIAS`
   - `SMIUNOTES_RELEASE_KEY_PASSWORD`
4. Choose the production API base and native auth rollout separately. Never embed a broker/service-role key or Vercel protection token in the app.
5. Test Android device QA with real staging accounts, cross-account notifications, revoked/expired sessions, four-device cap, protected notes and Community.
6. Configure and test native push opt-in and per-device unregister if push is required at launch. New-note alerts remain disabled.
7. Verify icon, privacy notice, package identity, build version, and permissions.
8. After the approved changes are merged to `main`, run Actions > Android Signed Release Candidate > Run workflow **on main**, entering `RELEASE_APPROVED` only after real-device and security QA. Verify bundle signing and Play Console upload checks before rollout.

## Fail-safe behavior
- Workflow signs only on `main` with explicit `RELEASE_APPROVED` confirmation. A GitHub Environment name is not an approval control by itself: configure required reviewers in Environment settings.
- Workflow refuses `com.example.*` application IDs, unapproved API origin, and absent signing secrets.
- `flutter analyze` and `flutter test` run before signing.
- Keystore exists only temporarily on CI runner and is deleted after the build; artifact contains only AAB.
- Without prerequisites, no production release should be issued.

## Pending acceptance
- Verified HTTPS backend, separate from Kamil staging
- Live OTP/Turnstile/auth refresh/logout and account revocation
- Notification ownership, private note reader URL expiry, Community permissions
- Android native push/device permissions if required
- Real-device QA, accessibility, signed bundle QA, store/privacy policies, owner approval

Current default debug APK is for UI preview QA, not a student production release.
