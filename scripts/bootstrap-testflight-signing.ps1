#Requires -Version 5.1
<#
.SYNOPSIS
  One-time TestFlight signing bootstrap for Windows (no Mac / no Xcode).

.DESCRIPTION
  Clears orphaned Apple Distribution certificates, enables a single CI cert
  creation run, then disables auto-creation again after TestFlight succeeds.

  Run from the repo root:
    .\scripts\bootstrap-testflight-signing.ps1 -Phase enable
    # merge fix, wait for TestFlight success
    .\scripts\bootstrap-testflight-signing.ps1 -Phase disable
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("enable", "disable", "status")]
    [string]$Phase,

    [string]$Repo = "Gaoridang/gumimap-v2"
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Number, [string]$Text) {
    Write-Host ""
    Write-Host "[$Number] $Text" -ForegroundColor Cyan
}

function Test-GhCli {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "gh CLI not found. Use GitHub web UI instead:" -ForegroundColor Yellow
        Write-Host "  Repo -> Settings -> Secrets and variables -> Actions -> Variables"
        return $false
    }
    return $true
}

function Get-RepoVariable([string]$Name) {
    if (-not (Test-GhCli)) { return $null }
    gh variable list --repo $Repo --json name,value `
        | ConvertFrom-Json `
        | Where-Object { $_.name -eq $Name } `
        | Select-Object -ExpandProperty value
}

switch ($Phase) {
    "status" {
        $value = Get-RepoVariable "ALLOW_CREATE_DISTRIBUTION_CERT"
        if ($null -eq $value) {
            Write-Host "ALLOW_CREATE_DISTRIBUTION_CERT is not set (CI will not create new certs)."
        } else {
            Write-Host "ALLOW_CREATE_DISTRIBUTION_CERT = $value"
        }
        exit 0
    }

    "enable" {
        Write-Host "TestFlight signing bootstrap (Windows)" -ForegroundColor Green
        Write-Host "Repo: $Repo"

        Write-Step "1" "Orphaned Distribution certificates (optional manual revoke)"
        Write-Host "  Fastfile revokes portal Distribution certs automatically when ALLOW=true."
        Write-Host "  Manual revoke only if bootstrap still fails:"
        Write-Host "  https://developer.apple.com/account/resources/certificates/list"

        Write-Step "2" "Merge the cert-reuse fix to main and wait for PR Build"
        Write-Host "  Branch: fix/testflight-cert-reuse"
        Write-Host "  PR: https://github.com/$Repo/compare/main...fix/testflight-cert-reuse"

        Write-Step "3" "Enable one-time cert creation for the next TestFlight run"
        if (Test-GhCli) {
            gh variable set ALLOW_CREATE_DISTRIBUTION_CERT --body "true" --repo $Repo
            Write-Host "Set ALLOW_CREATE_DISTRIBUTION_CERT=true via gh."
        } else {
            Write-Host "  Create repository variable:"
            Write-Host "    Name:  ALLOW_CREATE_DISTRIBUTION_CERT"
            Write-Host "    Value: true"
        }

        Write-Step "4" "Trigger TestFlight after merge"
        Write-Host "  Push to main, or:"
        Write-Host "  https://github.com/$Repo/actions/workflows/testflight.yml -> Run workflow"

        Write-Step "5" "After a successful run, disable auto-creation"
        Write-Host "  .\scripts\bootstrap-testflight-signing.ps1 -Phase disable"
        Write-Host ""
        Write-Host "The first success caches fastlane/signing; later runs reuse it." -ForegroundColor Green
    }

    "disable" {
        Write-Step "1" "Remove one-time cert creation flag"
        if (Test-GhCli) {
            gh variable delete ALLOW_CREATE_DISTRIBUTION_CERT --repo $Repo
            Write-Host "Deleted ALLOW_CREATE_DISTRIBUTION_CERT."
        } else {
            Write-Host "  Delete repository variable ALLOW_CREATE_DISTRIBUTION_CERT in GitHub Settings."
        }

        Write-Step "2" "Confirm cache on next TestFlight run"
        Write-Host "  Logs should show: Reusing cached distribution certificate"
        Write-Host "  https://github.com/$Repo/actions/workflows/testflight.yml"
    }
}