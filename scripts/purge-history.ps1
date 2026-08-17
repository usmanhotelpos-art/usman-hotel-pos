# Purges server/data DB files from git history (rewrites history, REQUIRES force push).
# Run from repo root. Git history rewrite is destructive - back up the repo first!
# NOTE: requires git-filter-repo (pip install git-filter-repo or https://github.com/newren/git-filter-repo)
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

try {
    Write-Host "Checking for git-filter-repo..."
    git filter-repo --version *> $null
    if (-not $?) { throw "git-filter-repo not found. Install it first: pip install git-filter-repo" }

    Write-Host "Purging database files from history..."
    git filter-repo --invert-paths `
        --path server/data/db.json `
        --path server/data/db.json.backup-2026-05-18-020341.json `
        --path server/data/db.json.backup-current-2026-05-18-022032.json `
        --path server/data/db.json.backup-extraCharge-before.json `
        --path server/data/db.json.restore-before.json

    Write-Host ""
    Write-Host "History purged locally. Now force-push ALL branches to GitHub:"
    Write-Host "  git push --force --all"
    Write-Host ""
    Write-Host "IMPORTANT: After this, ROTATE your JWT_SECRET and all staff passwords"
    Write-Host "because they were exposed in the old git history."
} finally {
    Pop-Location
}