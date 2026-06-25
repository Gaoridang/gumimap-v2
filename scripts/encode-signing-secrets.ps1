#Requires -Version 5.1
<#
.SYNOPSIS
  Encode signing files to GitHub secret values on Windows.

.DESCRIPTION
  Use when you received distribution.p12 and profile.mobileprovision from a Mac.
  For the no-Mac flow, prefer bootstrap-testflight-signing.ps1 instead.

.EXAMPLE
  .\scripts\encode-signing-secrets.ps1 `
    -P12Path "C:\path\distribution.p12" `
    -ProfilePath "C:\path\profile.mobileprovision" `
    -P12Password "your-ci-password"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$P12Path,

    [Parameter(Mandatory = $true)]
    [string]$ProfilePath,

    [Parameter(Mandatory = $true)]
    [string]$P12Password,

    [string]$OutputDir = ".ci-signing-export"
)

$ErrorActionPreference = "Stop"

function To-Base64Line([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Path))
    return [Convert]::ToBase64String($bytes)
}

if (-not (Test-Path $P12Path)) { throw "P12 not found: $P12Path" }
if (-not (Test-Path $ProfilePath)) { throw "Profile not found: $ProfilePath" }

$root = Split-Path $PSScriptRoot -Parent
if (Test-Path (Join-Path (Get-Location) "gumimap-v2.xcodeproj")) {
    $root = Get-Location
} elseif (Test-Path (Join-Path (Get-Location) "fastlane")) {
    $root = Get-Location
}

$out = Join-Path $root $OutputDir
New-Item -ItemType Directory -Force -Path $out | Out-Null

$p12B64 = To-Base64Line $P12Path
$profileB64 = To-Base64Line $ProfilePath

Set-Content -Path (Join-Path $out "BUILD_CERTIFICATE_BASE64.txt") -Value $p12B64 -NoNewline
Set-Content -Path (Join-Path $out "PROVISIONING_PROFILE_BASE64.txt") -Value $profileB64 -NoNewline
Set-Content -Path (Join-Path $out "P12_PASSWORD.txt") -Value $P12Password -NoNewline

Write-Host "Wrote secret payloads to: $out" -ForegroundColor Green
Write-Host ""
Write-Host "Add GitHub repository secrets:"
Write-Host "  BUILD_CERTIFICATE_BASE64      <- BUILD_CERTIFICATE_BASE64.txt"
Write-Host "  PROVISIONING_PROFILE_BASE64   <- PROVISIONING_PROFILE_BASE64.txt"
Write-Host "  P12_PASSWORD                  <- P12_PASSWORD.txt"
Write-Host ""
Write-Host "With gh CLI:"
Write-Host "  gh secret set BUILD_CERTIFICATE_BASE64 --repo Gaoridang/gumimap-v2 < `"$out\BUILD_CERTIFICATE_BASE64.txt`""
Write-Host "  gh secret set PROVISIONING_PROFILE_BASE64 --repo Gaoridang/gumimap-v2 < `"$out\PROVISIONING_PROFILE_BASE64.txt`""
Write-Host "  gh secret set P12_PASSWORD --repo Gaoridang/gumimap-v2 < `"$out\P12_PASSWORD.txt`""