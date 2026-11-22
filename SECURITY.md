# Security policy

SMIUNotes handles student identities and private media. Please report vulnerabilities responsibly.

## Report privately

**Do not open a public issue or post exploit details, credentials or personal records.** Use GitHub's **Security → Report a vulnerability** private advisory feature where enabled. If it is not available, contact a repository maintainer privately through an existing authorized channel; ask for a secure submission channel without including exploit details initially.

Include sanitized reproduction steps, affected route/version and impact. Do not attack live users, enumerate student records, upload malware, perform denial-of-service testing or retrieve other people's data. Use a disposable test account and environment.

## Scope and response

Maintainers will assess reproducible issues in authentication, authorization, Supabase RLS, private media and signed URLs, student verification, updates moderation, mobile API and deployment configuration. No specific response time, reward or bug bounty is promised.

## Maintainer release checklist

- Inspect all Git history and all branches/tags for secrets and private data before making a private repository public; never assume the current working tree is sufficient.
- Scan tracked files and CI artifacts, rotate/revoke any exposed secrets, and purge/rewrite history only after coordinating with all collaborators and backups.
- Review public Firebase client configuration restrictions separately from private Firebase service-account credentials.
- Protect `main` with PR reviews, CI checks and restricted direct pushes in GitHub settings.
- Keep production and staging credentials separate. Review RLS, least-privilege access, Turnstile, media signing, release signing and mobile/server API compatibility.
- If a secret is leaked, **rotate it first**. Deleting a current file cannot revoke credentials that already appeared in commit history or forks.

## Disclosure

Publish security fixes and advisories only after mitigations and necessary credential rotations are complete. Avoid disclosing student personal information or private content.
