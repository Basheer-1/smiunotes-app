# Website = Android app: public and student parity contract

Owner requirement (2026-11-22): every guest/student-facing website feature must be implemented as a native Flutter user experience and backed by the same live SMIUNotes data, access controls and business rules. A website URL shown in an external browser is **not feature parity**. WebView does not count. Keep exactly five bottom navigation tabs: Home, Notes, Updates, Community, Profile.

## Role-independent surface
Guest, student, contributor, admin and Updates Editor should all see the **same consumer app experience**. Existing account-specific identity, verification state and access permissions remain enforced server-side. No role-triggered new bottom tabs or management dashboards. Future contributor-only app is a distinct project. Existing roles remain visible in a profile as identity metadata.

## Feature-by-feature acceptance

| Website student/guest feature | Native Android status before this branch | Parity criterion |
| --- | --- | --- |
| Home, Explore, navigation | Partially native | All public quick links, search, current content previews |
| Browse notes by department, semester, subject, search | Native basic | Same filter dependencies, sort/search, list and empty states |
| Published note reading | Native | Server-authorized private/sensitive note pages, pagination, no unsafe download |
| Bookmark notes | Native and user-verified | Save/remove synchronized bidirectionally |
| **Completed** notes/study progress | Missing | Saved and completed independent flags, visible across web and app |
| Updates stream/category/search | Native basic | Image cards, event/deadline badges, search, sort, deadline filters, archive |
| Update article, Apply Now, source link | Native partial | Rich text metadata, approved HTTPS URLs and images, shared source of truth |
| Community list, discussion, replies | Native partial | Public read, verified create/reply, lock, ban and content validation |
| Contributors public directory, department Top 10 | Missing | Live public read-only directory and rankings with department/search/sort/pagination |
| Support | Native info screen only | Native method/amount/form/receipt upload and privacy-respecting supporter directory |
| Contact | Native info screen only | Native spam-protected form for guests and signed-in students |
| About, Privacy, Disclaimer | Missing | Native accessible pages with maintained website-consistent approved copy |
| Login, email registration/OTP, recovery | Native basic | Same account flows, rate limits, anti-bot and verified session handling |
| Profile identity, initials/photo, theme | Native partial | Same owner profile, photo upload/remove, local theme saved securely |
| Profile settings, devices and security | Native partial | Active sessions, revoke one/all, recovery, notification preferences |
| Student ID verification | Status only | Native card capture/upload, review status, deadline and lifecycle |
| Notification inbox | Native | Same list/read/clear and expected badge state, per-account security |
| Push notifications | Native; real device PASS | Permission, background, foreground, tap, opt-out, rotation and multiple accounts |
| Non-public admin, contributor and Updates Editor management | Explicitly excluded | Never embed these pages or create admin/staff/editor operations in the consumer app |

## Non-negotiable implementation rules
1. Use the existing published website's source data through versioned `/api/mobile/v1` routes and equivalent RLS; never copy production data into Flutter or invent local-only domain state.
2. Release parity requires functioning native actions—not cards that forward to `smiunotes.com`, not WebViews, not fake buttons. Use the system browser ONLY for genuinely external websites (e.g., applications, source notices) and banking apps.
3. Ship guest-facing features without login, gate account interactions with existing secure student flows, and show identical app navigation regardless of user role.
4. Never expose private student IDs, emails, receipts, drafts, storage paths, signed media tokens or FCM secrets in a public API.
5. Keep website behavior and app behavior aligned; apply data/permission changes on backend and separately test mobile response shapes.
6. Use Archive Blue design, modern native accessible cards, loading/empty/error/retry, semantic labels, 48dp touch targets, no overlong article-style screens.
7. Do not claim parity or close this checklist until all included rows have end-to-end Android acceptance, including real-device checks.
8. Do not publish a Play Store release before explicit owner approval.

## Practical implementation order
A. Public parity: Contributors, About/Privacy/Disclaimer, Home/Notes/Updates filter and article completeness.
B. Personal parity: completed notes, profile photo, devices, notification preferences, registration/recovery and student verification.
C. Transaction parity: native Contact + Support receipt upload (anti-abuse + signed-in/guest flows).
D. Accessibility, regression, security and multi-device QA.

Tracking: https://github.com/Basheer-1/smiunotes-app/issues/15 .

| University Updates notification preferences | Native in this increment | Same owner-only update announcements switch, essential/security alerts always on, new-note broadcasts always off |
