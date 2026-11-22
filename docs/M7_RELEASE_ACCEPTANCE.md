# M7 — Android beta and store release acceptance

This is the final Flutter-app milestone. **No automatic production publishing**.
Owner approval is mandatory for signing, Play Console upload and public rollout.

## Baseline already verified
- Flutter app M5/M6 features merged into `main`.
- Android debug QA: [M6 QA run](https://github.com/Basheer-1/smiunotes-app/actions/runs/44948512773) completed successfully (not a signed store release).
- Production API Vercel HTTPS host: `https://smiunotes.com`; separate from Kamil's staging work.
- M6: one real Android registered/received background + foreground FCM alert, notification tap opened the app, and opt-out removed the registered device; user confirmed.
- M5: user confirmed Website ↔ app Bookmark Sync PASS.
- FCM dispatch gate stays OFF; no recurring cron scheduled. Never treat one-device QA as mass-delivery approval.

## A. M5/M6 remaining feature acceptance
Record the date/device/OS, screen, action, expected result, and actual result for each:
1. Student login refresh/logout and account recovery; expired/revoked sessions must deny private operations.
2. Updates categories/streams/search/archived behavior on device; changing categories must reset pagination and show only published records.
3. Community: public read without login, verified student create/reply, locked-thread reply disabled, ban/rate limits effective.
4. Notes: published note viewer, sensitive notes blocked for unverified students, bookmarks save/remove synchronized both ways.
5. FCM: account-specific delivery, background and foreground, tap opens app, opted-out device removed, **token rotation and second-account/multi-device** still not tested.
6. Android connection loss and retry states on each tab.

## B. Security and privacy gates
- Verify HTTPS API only; production challenge/Turnstile and unauthorized mobile notification endpoints fail closed.
- Never bundle broker/service-role keys, FCM service account, signing passwords or production secrets in APK/AAB.
- Check Supabase RLS/reader grants, per-account bookmarks, notification ownership, signed reader URLs and Community permissions.
- Check manifest permissions: INTERNET and POST_NOTIFICATIONS only as necessary; document Play Console Data safety.
- Push is opt-in, has working opt-out, and excludes note-publication broadcasts.
- No background cron dispatch until owner approves after multi-device/revocation QA.

## C. Usability, performance and accessibility
- Test small Android screen, landscape/orientation, tablet layout, large font/text scaling and system dark mode.
- Test TalkBack labels, focus order and 48dp touch target on login, Notes, filters, notifications and Community composer.
- Test poor network, no network, resume from background, sign-out during a request and Android process recreation.
- Test PDF/WebP note pages on slower hardware, memory usage and page navigation, without casual file download.
- Check startup and transitions for jank using Flutter performance tools; record measured results rather than inventing thresholds.

## D. Signed release and Play Store readiness
- Confirm permanent Android package ID `com.smiunotes.app` is available and belongs to the correct Play Console account.
- Set release versionName/versionCode; current baseline `1.0.0+1` requires review, never reuse a versionCode for a new upload.
- Check launcher icons, app name, screenshots, privacy policy URL, contact details, content rating, target audience and data disclosure.
- Confirm original upload key is securely backed up. Keys/passwords must never enter a PR, conversation, logs or the app bundle.
- Protect GitHub Environment `android-release` with required reviewers and the four signing secrets.
- Configure exact `SMIUNOTES_RELEASE_API_BASE=https://smiunotes.com` and reviewed acceptance variables in that Environment.
- Run the existing manual `Android Signed Release Candidate` workflow ONLY after release gates and user approval.
- Inspect artifact signature, package ID, version, Play Console warnings and closed/internal track upload before public release.
- Release decision: **GO** only with captured device acceptance, security evidence, signed bundle and explicit owner approval.

## Status at M7 kickoff
Implementation is in QA/release preparation, **not** Play Store released. Open:
[M5 #8](https://github.com/Basheer-1/smiunotes-app/issues/8),
[M6 #10](https://github.com/Basheer-1/smiunotes-app/issues/10),
[M7 #12](https://github.com/Basheer-1/smiunotes-app/issues/12).
