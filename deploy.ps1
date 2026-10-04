# One-time deploy of the LCA of Emerging Technologies website to GitHub Pages.
# Run this in Windows PowerShell from D:\Projects1\ailca
#
#   cd D:\Projects1\ailca
#   .\deploy.ps1
#
# To use a different repository name, edit the line below.

$RepoName = "lca-emerging-tech"

# Native tools such as gh and git write status to stderr even when they
# succeed. PowerShell 5.1 would treat that as a fatal error, so this script
# never relies on PowerShell error handling and checks exit codes instead.
$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Note($msg) { Write-Host $msg -ForegroundColor Yellow }
function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

# --- 1. Prerequisites ---------------------------------------------------------
Step "Checking for git and the GitHub CLI"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "git is not installed. Install it with:  winget install --id Git.Git"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Note "The GitHub CLI is not installed. Installing it now."
    winget install --id GitHub.cli --accept-source-agreements --accept-package-agreements
    Note "`nInstalled. Close this window, open a new PowerShell, and run .\deploy.ps1 again"
    Note "so that the new gh command is on your PATH."
    exit 0
}
Write-Host "Both found."

# --- 2. Sign in ---------------------------------------------------------------
Step "Checking your GitHub sign-in"

# The real test is whether gh can call the API as you. (gh auth status exits
# with an error if ANY stored credential is stale, even when the active one works.)
function Get-GhUser {
    $out = gh api user --jq .login 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    $u = "$($out | Select-Object -First 1)".Trim()
    if ($u -match '^[A-Za-z0-9-]+$') { return $u }
    return $null
}

$User = Get-GhUser
if (-not $User) {
    Note "Not signed in. A browser window will open. Choose GitHub.com, then HTTPS, then authenticate."
    gh auth login --hostname github.com --git-protocol https --web
    $User = Get-GhUser
}
if (-not $User) {
    Note "gh still cannot reach the API. Details:"
    gh auth status 2>&1 | ForEach-Object { Write-Host "  $_" }
    Fail "Fix the sign-in shown above (often: gh auth logout, then gh auth login), then rerun this script."
}
Write-Host "Signed in as $User"

$null = gh auth setup-git 2>&1

$SiteUrl = "https://$User.github.io/$RepoName/"
$RepoUrl = "https://github.com/$User/$RepoName"

# --- 3. Point the site config at the real address -----------------------------
Step "Setting site-url and repo-url in _quarto.yml"

if (-not (Test-Path _quarto.yml)) { Fail "_quarto.yml not found. Run this from D:\Projects1\ailca" }

$cfg = Get-Content _quarto.yml -Raw
$cfg = $cfg -replace '(?m)^(\s*)site-url:.*$', "`$1site-url: `"$SiteUrl`""
$cfg = $cfg -replace '(?m)^(\s*)repo-url:.*$', "`$1repo-url: `"$RepoUrl`""
Set-Content _quarto.yml -Value $cfg -NoNewline -Encoding UTF8
Write-Host "site-url: $SiteUrl"
Write-Host "repo-url: $RepoUrl"

# --- 4. Local repository ------------------------------------------------------
Step "Preparing the local git repository"

if (-not (Test-Path .git)) {
    $null = git init 2>&1
    if ($LASTEXITCODE -ne 0) { Fail "git init failed." }
}

$null = git add -A 2>&1

$null = git diff --cached --quiet 2>&1
if ($LASTEXITCODE -ne 0) {
    $null = git -c user.name="$User" -c user.email="$User@users.noreply.github.com" commit -m "Publish LCA of Emerging Technologies working group website" 2>&1
    if ($LASTEXITCODE -ne 0) { Fail "git commit failed." }
    Write-Host "Committed."
} else {
    Write-Host "Nothing new to commit."
}

$null = git branch -M main 2>&1

# --- 5. Create the repository on GitHub and push ------------------------------
Step "Creating $User/$RepoName on GitHub and pushing"

$null = gh repo view "$User/$RepoName" 2>&1
$exists = ($LASTEXITCODE -eq 0)

$hasOrigin = $false
$remotes = git remote 2>&1
if ($LASTEXITCODE -eq 0 -and ("$remotes" -split "`r?`n" | Where-Object { $_.Trim() -eq 'origin' })) { $hasOrigin = $true }

if ($exists) {
    Write-Host "Repository already exists on GitHub."
    if (-not $hasOrigin) { $null = git remote add origin "$RepoUrl.git" 2>&1 }
    git push -u origin main 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) { Fail "Push failed. See the output above." }
} else {
    if ($hasOrigin) { $null = git remote remove origin 2>&1 }
    gh repo create "$RepoName" --public --source=. --remote=origin --push --description "Website of the LCA of Emerging Technologies working group (ACLCA)" 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) { Fail "Could not create or push to the repository. See the output above." }
}
Write-Host "Pushed."

# --- 6. Turn on Pages with GitHub Actions as the source -----------------------
Step "Turning on GitHub Pages (source: GitHub Actions)"

$null = gh api -X POST "repos/$User/$RepoName/pages" -f build_type=workflow 2>&1
$pagesOk = ($LASTEXITCODE -eq 0)
if (-not $pagesOk) {
    $null = gh api -X PUT "repos/$User/$RepoName/pages" -f build_type=workflow 2>&1
    $pagesOk = ($LASTEXITCODE -eq 0)
}
if ($pagesOk) {
    Write-Host "Pages is on, building from the Action."
} else {
    Note "Could not set Pages automatically. Open this page:"
    Note "  $RepoUrl/settings/pages"
    Note "and under 'Build and deployment' set Source to 'GitHub Actions'."
}

# --- 7. Report ----------------------------------------------------------------
Step "Done"

Write-Host "Watch the build:  $RepoUrl/actions"
Write-Host "Site will be at:  $SiteUrl" -ForegroundColor Green
Write-Host "`nThe push already started the build; it takes two to three minutes."
Write-Host "Every later commit to main republishes the site by itself."
Write-Host "`nTo follow the build from here:  gh run watch --repo $User/$RepoName"
