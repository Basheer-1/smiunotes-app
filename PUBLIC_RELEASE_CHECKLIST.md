# Public-source release readiness — 22 November 2026

**Status: HOLD for website; mobile repository was already public before this review.**

This is a release gate, not a claim of comprehensive security certification.

## Completed

- [x] Modern maintainer README and cross-repository architecture/learning guide
- [x] MIT LICENSE, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md
- [x] Hardened root .gitignore for operator secrets, signing materials and sensitive exports
- [x] Read-only Git history credential scanner and dedicated GitHub Actions job
- [x] Reviewed current Git tree for high-risk filenames; sampled historical tree snapshots
- [x] Mobile: dedicated historical credential scan **passed** on GitHub Actions (run 45042728293)

## Blocking verification before making the website public

- [ ] Website GitHub Actions runner must execute. On 22 Nov, dedicated history audit run 45042842229 **failed before any steps ran** (runner_id=0, zero steps). This is NOT a credential scan result. Check repository Actions UI for the failed job's setup/billing/policy message, then re-run.
- [ ] Complete history audit on all reachable refs (branches and tags), including historical blobs and large/binary files; examine findings privately and rotate any exposed credentials before release. The scanner skips blobs >1 MiB and is pattern-based, so supplement with a comprehensive secrets tool and manual review.
- [ ] Review current and historical documentation for personal identities, student records, verification data, receipts, tokens, internal endpoints and deployment metadata. Public config is not itself a privileged credential.
- [ ] Confirm license eligibility, ownership of contributions, bundled fonts/images and third-party materials; MIT applies to this repository's software, not university branding or students' uploaded documents.
- [ ] Verify Supabase RLS and storage policies, R2 bucket controls, Turnstile, authentication, roles, mobile API controls and backups against the actual production environment.
- [ ] Set GitHub branch ruleset/protection for main: required PRs, review(s), passing CI, no force push, no deletion. Enable private vulnerability reporting and secret scanning/Dependabot where available.
- [ ] Confirm build, test, security and operational smoke checks pass on current commits; Flutter installed APK verification is separate from code checks.
- [ ] Verify all known exposed secrets are revoked/rotated and check any existing forks, public artifacts and CI logs.
- [ ] Repository owner explicitly approves visibility switch after the release report passes.

## How to publish (owner action only after green gates)

In the **website GitHub repository**, open **Settings → General → Danger Zone → Change repository visibility → Make public**. Follow confirmation dialogs. The public change is irreversible with respect to any secrets or private records already copied by third parties. Do not perform this before the completed audit. The mobile repository was **already public** during this review; no visibility switch is required for it.

The currently connected GitHub integration supports repository/file writes but **does not expose a repository-visibility mutation or branch protection setting action**. Those settings must be completed by the owner in GitHub.

## CI diagnostic evidence

- Before hardening, website Verify CypherNotes run 45024256926 succeeded with an assigned runner.
- After documentation updates, website audit run 45042842229 failed at runner provisioning with 0 steps; cause is not available through the repository-content API.
- Mobile Git-history scan 45042728293 completed successfully on an assigned runner.
- Do not interpret a pre-start failure as proof of leaked credentials, or as proof that credentials are safe.

Re-check this list and record the production release commit when the hold is lifted.

## Follow-up verification — 22 November 2026 (16:32 UTC)

- Website isolated security CI run 45042927556 was retried (attempt 2) and still finished **failure before any steps were executed**; it is an infrastructure/settings blocker, **not a scan finding**. Check the run's job-level GitHub UI setup annotation and account Actions usage/billing/repository settings. Do not suppress the scan or claim a pass.
- GitHub API reports **403: Upgrade to GitHub Pro or make this repository public to enable this feature** for private website rulesets. Do not pay or make public merely to bypass the audit gate. After safe release, public repository rulesets may be configured by the owner.
- The connected GitHub integration cannot update repository visibility or branch protection; GitHub repository owner must perform those settings changes once audit gates are satisfied.
- Public mobile repository currently returns an empty rulesets list, so main branch protection remains an actionable owner-level task.
