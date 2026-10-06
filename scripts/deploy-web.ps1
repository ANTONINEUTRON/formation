#Requires -Version 5.1
<#
.SYNOPSIS
  Builds and deploys the Formation web app to Firebase Hosting.

.DESCRIPTION
  Three steps, in order, because each depends on the last:
    1. Bundle the Wallet Standard bridge  -> app/web/wallet_bridge.js
    2. Build the Flutter web app          -> app/build/web
    3. Deploy the `app` hosting target

  First-time setup, once per project:
    firebase login
    firebase hosting:sites:create formation-app
    # then add app.formation.titalabs.xyz to that site in the Firebase console

  The landing page is a separate target and is left alone:
    firebase deploy --only hosting:landing

  Share previews are the generic ones in app/web/index.html, so every shared
  link unfurls the same card. Per-page previews need something server-side that
  can rewrite the head before a crawler reads it; functions/ holds a Cloud
  Function that does exactly that, but it is deliberately not referenced from
  firebase.json or from this script, so nothing here requires a billing
  account. See README for the two options when that gets picked up again.

.PARAMETER RpcUrl
  Solana RPC for the web build. The public endpoint rate-limits by origin and a
  browser hits that far sooner than the APK does, so pass a dedicated one
  (Helius or similar) for anything player-facing.

.PARAMETER SkipDeploy
  Build everything and stop, for checking the output before it goes live.

.EXAMPLE
  ./scripts/deploy-web.ps1 -RpcUrl "https://mainnet.helius-rpc.com/?api-key=..."
#>
[CmdletBinding()]
param(
  [string]$ApiUrl = 'https://api.formation.titalabs.xyz',
  [string]$RpcUrl = '',
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

if (-not $RpcUrl) {
  Write-Warning "No -RpcUrl given: the build will use the public mainnet endpoint, which rate-limits browser origins. Fine for a smoke test, not for players."
}

Invoke-Step 'Bundling the wallet bridge' {
  npm --prefix "$repo/app/web_wallet" install --no-audit --no-fund
  npm --prefix "$repo/app/web_wallet" run build
}

Invoke-Step 'Building the Flutter web app' {
  $defines = @("--dart-define=API_URL=$ApiUrl")
  if ($RpcUrl) {
    $defines += "--dart-define=SOLANA_RPC_URL=$RpcUrl"
    # The websocket host follows the RPC host, or balance subscriptions would
    # still be pointed at the throttled public endpoint.
    $defines += "--dart-define=SOLANA_WS_URL=$($RpcUrl -replace '^https:', 'wss:')"
  }
  Push-Location "$repo/app"
  try { flutter build web --release @defines } finally { Pop-Location }
}

if ($SkipDeploy) {
  Write-Host ""
  Write-Host "Built, not deployed (-SkipDeploy). Output: app/build/web" -ForegroundColor Yellow
  exit 0
}

Invoke-Step 'Deploying to Firebase' {
  Push-Location $repo
  try { firebase deploy --only "hosting:app" } finally { Pop-Location }
}

Write-Host ""
Write-Host "Deployed: https://app.formation.titalabs.xyz" -ForegroundColor Green
