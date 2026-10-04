# Publishes the website from the lca-emerging-tech organization at the root address
#   https://lca-emerging-tech.github.io/
#
#   cd D:\Projects1\ailca
#   .\move-to-lca-org.ps1
#
# This does NOT transfer the disabled SARWLabs repo. It creates a fresh repo in
# the new organization and pushes your local copy, which has the full history.
# Safe to rerun: every step checks whether it is already done.

$Org      = "lca-emerging-tech"
$RepoName = "lca-emerging-tech.github.io"   # this exact name gives the root address

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Note($msg) { Write-Host $msg -ForegroundColor Yellow }
function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

if (-not (Test-Path _quarto.yml)) { Fail "_quarto.yml not found. Run this from D:\Projects1\ailca" }

$Full    = "$Org/$RepoName"
$SiteUrl = "https://$Org.github.io/"
$RepoUrl = "https://github.com/$Full"

# --- 1. Sign-in and role ------------------------------------------------------
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
if ($role -ne "admin") { Fail "You need to be an owner of $Org (your role: '$role')." }
Write-Host "You are an owner of $Org."

# --- 2. Create the repo -------------------------------------------------------
Step "Creating $Full"

$null = gh api "repos/$Full" --jq .full_name 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Already exists. Reusing it."
} else {
    gh repo create $Full --public --description "Website of the LCA of Emerging Technologies working group (ACLCA)" 2>&1 |
        ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) { Fail "Could not create the repo. See the output above." }
    Write-Host "Created."
}

# --- 3. Point the site and your local copy at the new location ---------------
Step "Updating _quarto.yml and your local git remote"

$cfg = Get-Content _quarto.yml -Raw
$cfg = $cfg -replace '(?m)^(\s*)site-url:.*$', "`$1site-url: `"$SiteUrl`""
$cfg = $cfg -replace '(?m)^(\s*)repo-url:.*$', "`$1repo-url: `"$RepoUrl`""
Set-Content _quarto.yml -Value $cfg -NoNewline -Encoding UTF8
Write-Host "site-url: $SiteUrl"
Write-Host "repo-url: $RepoUrl"

$null = git remote set-url origin "$RepoUrl.git" 2>&1
if ($LASTEXITCODE -ne 0) { $null = git remote add origin "$RepoUrl.git" 2>&1 }
Write-Host "origin -> $RepoUrl.git"

$null = git add -A 2>&1
$null = git diff --cached --quiet 2>&1
if ($LASTEXITCODE -ne 0) {
    $null = git -c user.name="$User" -c user.email="$User@users.noreply.github.com" commit -m "Publish from the $Org organization at $SiteUrl" 2>&1
    if ($LASTEXITCODE -ne 0) { Fail "git commit failed." }
    Write-Host "Committed."
}

# --- 4. Turn on Pages (may only succeed once the repo has content) ------------
function Enable-Pages {
    $bt = gh api "repos/$Full/pages" --jq .build_type 2>&1
    if ($LASTEXITCODE -eq 0 -and "$bt".Trim() -eq "workflow") { return $true }
    $null = gh api -X POST "repos/$Full/pages" -f build_type=workflow 2>&1
    if ($LASTEXITCODE -eq 0) { return $true }
    $null = gh api -X PUT "repos/$Full/pages" -f build_type=workflow 2>&1
    return ($LASTEXITCODE -eq 0)
}

Step "Turning on GitHub Pages"
$pagesOn = Enable-Pages
if ($pagesOn) { Write-Host "Pages is on." } else { Write-Host "Will retry after the push (an empty repo cannot have Pages yet)." }

# --- 5. Push -----------------------------------------------------------------
Step "Pushing"

$push = git push -u origin main 2>&1
$push | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -ne 0) {
    if ("$push" -match "disabled") {
        Fail "GitHub has disabled repos in $Org too. That is an account check on GitHub's side, not a script problem. See https://github.com/organizations/$Org/settings/billing and contact https://support.github.com"
    }
    Fail "Push failed. See the output above."
}
Write-Host "Pushed."

if (-not $pagesOn) {
    Step "Turning on GitHub Pages (second try)"
    if (Enable-Pages) {
        Write-Host "Pages is on. Starting a fresh build so it deploys."
        $null = gh workflow run "Publish site" --repo $Full 2>&1
    } else {
        Note "Could not set Pages automatically. Open $RepoUrl/settings/pages, set Source to 'GitHub Actions',"
        Note "then on the Actions tab run 'Publish site' by hand."
    }
}

# --- 6. Report ----------------------------------------------------------------
Step "Done"
Write-Host "Watch the build:  $RepoUrl/actions"
Write-Host "New address:      $SiteUrl" -ForegroundColor Green
Write-Host "`nThe build takes two to three minutes."
Write-Host "To follow it from here:  gh run watch --repo $Full"
