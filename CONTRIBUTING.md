# Contributing to SMIUNotes

Thank you for improving this independent student-run educational project.

## Before opening a pull request

1. Read [README.md](README.md), [SECURITY.md](SECURITY.md) and the README of the companion repository.
2. Open an issue (without student data or secret values) describing the change, expected behavior and scope. For a security vulnerability, use the **private reporting procedure** in SECURITY.md instead of an issue.
3. Fork or branch from current `main`. Use `feat/`, `fix/`, `test/` or `docs/` and create a focused PR; do not push directly to production branches.
4. Provide reproduction steps, screenshots for UI changes, tests, affected endpoints, privacy impact and backward compatibility. Check both the web and mobile clients when a shared API changes.
5. Do not commit credentials, signing keys, database exports, student records, payment receipts, private notes, privileged signed URLs or personal verification images, even in test fixtures.
6. Obtain permission before using university marks, photographs, student materials or other third-party content. The MIT source-code license does **not** grant rights to unrelated brand marks, user-provided notes or third-party media.
7. Respect accessibility, clear errors, privacy and least privilege. Authentication/authorization must be enforced server-side; never weaken RLS or disable anti-abuse protection for convenience.
8. Maintainers review CI and deployment impact. Only the designated owner approves production releases, schema migrations and store distribution.

## Review expectations

All PRs must be reviewable and explain how they were tested and rolled back. Small, additive, backward-compatible changes are preferred. Do not include production secrets or personally identifying debug output. The owner may request revisions or decline changes.

## Ownership and license

By submitting a contribution, you agree to license that contribution under this repository's MIT License, to the extent that you have the rights to do so. Retain third-party license notices and attribution. Do not submit code or files you do not have permission to license.
