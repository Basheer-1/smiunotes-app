# SMIUNotes Android — M4 tester handoff

## Build identity and safety
- This is a **debug QA APK**, not a Play Store or production release.
- Download the artifact from the **latest passing** Android Debug Build workflow for branch `feat/m4-notifications-release`. Verify the head SHA matches the tested commit. Avoid sharing an earlier APK under a newer version label.
- The default build has no configured mobile API base, no live student authentication, no native Android push, and no embedded access tokens.
- New artifact `smiunotes-m4-qa-debug-apk` contains `app-debug.apk`, `BUILD-INFO.txt` and `SHA256SUMS.txt`. Verify the commit in BUILD-INFO matches the GitHub workflow and optionally verify SHA-256 before sharing. An APK extracted from an older `m2` artifact is not the latest build.
- No production branch or Kamil staging was changed by M4 work. Do not request real student credentials in this build.
- GitHub artifact retention is currently seven days.

## Smoke test matrix
| Area | Expected on default debug APK |
|---|---|
| Install / open / cold start | Installs and launches without crashes |
| Home | Archive Blue branding, visible *M4 testing build / Preview mode* notice |
| Navigation | Home, Notes, Updates, Community, Profile reachable; no overflow |
| Notes | Responsive filters, loading and error/empty states; no live data without configured staging API |
| Updates | Search, lists, responsive details where test data exists; no live data without configured staging API |
| Community | Read-only UI and appropriate error state; posting requires verified auth in separate staging build |
| Profile | Logged-out / disabled-staging state, no student data leaked |
| Notifications | Bell opens access-required preview, without guest network requests |
| Offline | Recoverable API error, no freezes or crash |
| Rotation & screen size | Layout and Back navigation across typical Android sizes |

## Authenticated staging acceptance (separate, explicitly configured APK)
- Use an approved device-accessible HTTPS **isolated staging** endpoint and dedicated test accounts, never production credentials.
- Confirm Turnstile, OTP, recovery, session refresh, sign-out, revoked-account denial and four-device cap.
- Verify ownership: user A cannot read, mark or clear user B notifications; expired/revoked bearer token returns denial.
- Test authenticated note reader and Community posting with real published/draft permission boundaries.
- Test notification read/clear while online, and failures/offline recovery. No new-note broadcast push.
- Android native push opt-in, permission prompts, device registration/unregistration and delivery remain **not implemented / not accepted**; do not mark pass.

## Tester bug report format
Phone model; Android version; build commit SHA; screen/feature; exact steps; observed result; expected result; screenshot or recording without OTP, credentials, tokens or private student information.

## Release blockers
- Device-facing staging URL and security/integration tests
- Native push design/infrastructure and per-device opt-in/unregister
- Real Android device QA across sizes and OS versions
- Signed release AAB/APK, package identity, store metadata/privacy, production approval

Default debug APK is for **UI and public-screen preview QA only**. It is not an end-to-end release candidate.
