#Requires -Version 5.1
<#
.SYNOPSIS
  Builds and deploys the Formation web app to Firebase Hosting.

.DESCRIPTION
  Four steps, in order, because each depends on the last:
    1. Bundle the Wallet Standard bridge  -> app/web/wallet_bridge.js
    2. Build the Flutter web app          -> app/build/web
    3. Compile the Open Graph renderer    -> functions/lib
    4. Deploy the `app` hosting target and the ogRender function

  First-time setup, once per project:
    firebase login
    firebase hosting:sites:create formation-app
    # then add app.formation.titalabs.xyz to that site in the Firebase console
  Cloud Functions need the Blaze plan on formation-cbf24.

  The landing page is a separate target and is left alone:
    firebase deploy --only hosting:landing

  ogRender gives each shared manager and league link its own preview card: a
  crawler never runs Flutter, so the function writes that page's title and
  description into the app shell's head before serving it. Hosting rewrites
  /managers/** and /leagues/** to it, so the function must be deployed
  together with hosting - which this script does.

  Configuration comes from app/.env (see app/.env.example), compiled into the
  Env class by build_runner - which this script runs, so an edit to .env is
  picked up without a separate step.

.PARAMETER SkipDeploy
  Build everything and stop, for checking the output before it goes live.

.EXAMPLE
  ./scripts/deploy-web.ps1
#>
[CmdletBinding()]
param(
  [switch]$SkipDeploy
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

function Invoke-Step {
  param([string]$Name, [scriptblock]$Body)
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  & $Body
  if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE" }
}

# Catch the easy mistake before spending four minutes on a build: shipping the
# public RPC, which rate-limits per origin and will start dropping balance
# reads once more than a handful of people are playing.
$envFile = "$repo/app/.env"
if (-not (Test-Path $envFile)) {
  Write-Warning "No app/.env - building against the public Solana endpoint. Copy app/.env.example and set SOLANA_RPC_URL before this goes to players."
} elseif ((Get-Content $envFile -Raw) -match 'SOLANA_RPC_URL\s*=\s*https://api\.mainnet-beta\.solana\.com') {
  Write-Warning "app/.env still has the public SOLANA_RPC_URL, which rate-limits browser origins. Fine for a smoke test, not for players."
}

Invoke-Step 'Bundling the wallet bridge' {
  npm --prefix "$repo/app/web_wallet" install --no-audit --no-fund
  npm --prefix "$repo/app/web_wallet" run build
}

Invoke-Step 'Generating config from .env' {
  Push-Location "$repo/app"
  try { dart run build_runner build --delete-conflicting-outputs } finally { Pop-Location }
}

Invoke-Step 'Building the Flutter web app' {
  Push-Location "$repo/app"
  try { flutter build web --release } finally { Pop-Location }
}

Invoke-Step 'Compiling the Open Graph renderer' {
  npm --prefix "$repo/functions" install --no-audit --no-fund
  npm --prefix "$repo/functions" run build
}

if ($SkipDeploy) {
  Write-Host ""
  Write-Host "Built, not deployed (-SkipDeploy). Output: app/build/web" -ForegroundColor Yellow
  exit 0
}

Invoke-Step 'Deploying to Firebase' {
  Push-Location $repo
  try { firebase deploy --only "hosting:app,functions:ogRender" } finally { Pop-Location }
}

Write-Host ""
Write-Host "Deployed: https://app.formation.titalabs.xyz" -ForegroundColor Green
