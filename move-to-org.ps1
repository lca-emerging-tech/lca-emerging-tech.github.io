# Moves the website repo from your personal account into the SARWLabs
# organization and republishes it there.
#
#   cd D:\Projects1\ailca
#   .\move-to-org.ps1
#
# New address:  https://sarwlabs.github.io/lca-emerging-tech/
# Safe to rerun: every step checks whether it is already done.

$Org      = "SARWLabs"
$RepoName = "lca-emerging-tech"

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Note($msg) { Write-Host $msg -ForegroundColor Yellow }
function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

if (-not (Test-Path _quarto.yml)) { Fail "_quarto.yml not found. Run this from D:\Projects1\ailca" }

# --- 1. Who you are, and your role in the organization ------------------------
Step "Checking your sign-in and your role in $Org"

$out = gh api user --jq .login 2>&1
if ($LASTEXITCODE -ne 0) { Fail "gh cannot reach GitHub as you. Run: gh auth login" }
$User = "$($out | Select-Object -First 1)".Trim()
Write-Host "Signed in as $User"

$role = gh api "user/memberships/orgs/$Org" --jq .role 2>&1
if ($LASTEXITCODE -ne 0) {
    Note "Could not read your membership in $Org. Refreshing permissions; a browser window may open."
    gh auth refresh -h github.com -s read:org
    $role = gh api "user/memberships/orgs/$Org" --jq .role 2>&1
}
$role = "$($role | Select-Object -First 1)".Trim()
if ($role -ne "admin") { Fail "You need to be an owner of $Org to move a repo into it (your role: '$role')." }
Write-Host "You are an owner of $Org."

$NewFull = "$Org/$RepoName"
$OldFull = "$User/$RepoName"
$Host_   = $Org.ToLower()
$SiteUrl = "https://$Host_.github.io/$RepoName/"
$RepoUrl = "https://github.com/$NewFull"

# --- 2. Transfer ---------------------------------------------------------------
Step "Moving $OldFull to $NewFull"

$null = gh api "repos/$NewFull" --jq .full_name 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Already in $Org. Skipping the transfer."
} else {
    $null = gh api -X POST "repos/$OldFull/transfer" -f new_owner=$Org 2>&1
    if ($LASTEXITCODE -ne 0) { Fail "GitHub refused the transfer. Check https://github.com/$OldFull/settings (Danger Zone, Transfer)." }

    # The transfer finishes in the background; wait for it.
    $done = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 2
        $full = gh api "repos/$NewFull" --jq .full_name 2>&1
        if ($LASTEXITCODE -eq 0 -and "$full".Trim() -eq $NewFull) { $done = $true; break }
    }
    if (-not $done) { Fail "Transfer started but has not finished after a minute. Wait a moment and rerun this script." }
    Write-Host "Moved."
}

# --- 3. Point your local copy at the new location -----------------------------
Step "Updating your local git remote"

$null = git remote set-url origin "$RepoUrl.git" 2>&1
if ($LASTEXITCODE -ne 0) { $null = git remote add origin "$RepoUrl.git" 2>&1 }
Write-Host "origin -> $RepoUrl.git"

# --- 4. Make sure Pages is on BEFORE pushing, so the build deploys cleanly -----
Step "Making sure GitHub Pages is on in $Org"

$bt = gh api "repos/$NewFull/pages" --jq .build_type 2>&1
if ($LASTEXITCODE -eq 0 -and "$bt".Trim() -eq "workflow") {
    Write-Host "Pages is on, building from the Action."
} else {
    $null = gh api -X POST "repos/$NewFull/pages" -f build_type=workflow 2>&1
    if ($LASTEXITCODE -ne 0) { $null = gh api -X PUT "repos/$NewFull/pages" -f build_type=workflow 2>&1 }
    if ($LASTEXITCODE -eq 0) { Write-Host "Pages is on." }
    else { Note "Could not set Pages automatically. Open $RepoUrl/settings/pages and set Source to 'GitHub Actions'." }
}

# --- 5. Update the site's own address and push ---------------------------------
Step "Setting site-url and repo-url in _quarto.yml"

$cfg = Get-Content _quarto.yml -Raw
$cfg = $cfg -replace '(?m)^(\s*)site-url:.*$', "`$1site-url: `"$SiteUrl`""
$cfg = $cfg -replace '(?m)^(\s*)repo-url:.*$', "`$1repo-url: `"$RepoUrl`""
Set-Content _quarto.yml -Value $cfg -NoNewline -Encoding UTF8
Write-Host "site-url: $SiteUrl"
Write-Host "repo-url: $RepoUrl"

$null = git add -A 2>&1
$null = git diff --cached --quiet 2>&1
if ($LASTEXITCODE -ne 0) {
    $null = git -c user.name="$User" -c user.email="$User@users.noreply.github.com" commit -m "Move site to the $Org organization" 2>&1
    if ($LASTEXITCODE -ne 0) { Fail "git commit failed." }
    git push -u origin main 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) { Fail "Push failed. See the output above." }
    Write-Host "Pushed. The push starts the build."
} else {
    Write-Host "Nothing new to commit. Starting a build by hand."
    $null = gh workflow run "Publish site" --repo $NewFull 2>&1
}

# --- 6. Report ----------------------------------------------------------------
Step "Done"

Write-Host "Watch the build:  $RepoUrl/actions"
Write-Host "New address:      $SiteUrl" -ForegroundColor Green
Write-Host "`nThe build takes two to three minutes."
Write-Host "The old shatadkp.github.io address stops working; GitHub does not redirect Pages sites."
Write-Host "`nTo follow the build from here:  gh run watch --repo $NewFull"
