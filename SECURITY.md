# Security

Security policies for the Usman Hotel POS project.

## Reporting a Vulnerability

Do NOT open a public GitHub issue for security problems. Contact the repository
owner directly (private message / email) with details of the issue, affected
endpoints, and a proof of concept if available.

## Current Security Controls

- **Passwords are hashed** with bcrypt (`passwordHash`). Plain-text `password`
  and `rawPassword` fields are migrated to hashes and stripped automatically at
  startup (`server/db.js` -> `migrateLegacyPasswords`).
- **JWT secret** is read from `JWT_SECRET` env var (via `server/.env`, gitignored).
  If missing, a random secret is generated and stored in `server/data/.jwt-secret`
  (gitignored). There is NO hardcoded fallback secret.
- **Login rate limiting**: max 5 failed login attempts per IP per 15 minutes
  (`server/routes.js` -> `checkLoginRateLimit`), applies to `/auth/login` and
  `/auth/rider-login`.
- **HTTP hardening headers** via `helmet` on the API server.
- **Database file is never committed**: `server/data/*.json` is gitignored.
  Only `server/data/README.md` is tracked.

## Rules For Contributors

1. NEVER commit `server/data/db.json` or any backup/json under `server/data/`.
2. NEVER commit `.env` files or any real secret. Only `.env.example` (with
   placeholders) may be committed.
3. NEVER store passwords in plain text. Always use `bcrypt.hash` and store as
   `passwordHash`.
4. If you add `console.log`/`console.error` output, make sure it does not leak
   tokens, passwords, or personal customer data (logs in `server_out.txt` etc.
   are gitignored).
5. Run `npm audit` before pushing and fix high-severity production issues.
6. If you accidentally push a secret or the database file, rotate every exposed
   credential and purge git history (see below) before the change is pulled by
   anyone else.

## History Purge (only needed if a secret was pushed historically)

The database file was tracked in git history in the past. To fully remove it
from history (this rewrites history and requires a force-push):

```bash
git filter-repo --invert-paths --path server/data/db.json --path server/data/db.json.backup-2026-05-18-020341.json --path server/data/db.json.backup-current-2026-05-18-022032.json --path server/data/db.json.backup-extraCharge-before.json --path server/data/db.json.restore-before.json
git push --force --all
```

(or use `scripts/purge-history.ps1`)

After purging, also **rotate the JWT secret** and any production passwords,
since they were exposed in the repository.