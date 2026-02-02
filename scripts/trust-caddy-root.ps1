<#
.SYNOPSIS
  Trust the Caddy internal root certificate on Windows.

.DESCRIPTION
  Imports the certificate into the LocalMachine or CurrentUser Trusted Root store.
  By default it targets the repository-relative location `caddy/data/pki/authorities/local/root.crt`.

.EXAMPLE (Admin)
  Open PowerShell as Administrator and run:
    .\scripts\trust-caddy-root.ps1 -CertPath .\caddy\data\pki\authorities\local\root.crt -Scope LocalMachine

.EXAMPLE (Non-admin)
  Run without admin privileges and import to the current user store:
    .\scripts\trust-caddy-root.ps1 -CertPath .\caddy\data\pki\authorities\local\root.crt -Scope CurrentUser
#>

param(
    [string]
    $CertPath = "${PSScriptRoot}\..\caddy\data\pki\authorities\local\root.crt",

    [ValidateSet('LocalMachine','CurrentUser')]
    [string]
    $Scope = 'LocalMachine'
)

function Assert-FileExists {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "Certificate file not found: $Path"
        exit 2
    }
}

Assert-FileExists -Path $CertPath

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($Scope -eq 'LocalMachine' -and -not $isAdmin) {
    Write-Warning "LocalMachine scope requires Administrator privileges. Re-run PowerShell as Administrator or use -Scope CurrentUser to import for the current user."
    exit 3
}

try {
    $storePath = "Cert:\$Scope\Root"
    Write-Host "Importing certificate '$CertPath' into $storePath ..."
    $cert = Import-Certificate -FilePath $CertPath -CertStoreLocation $storePath -Verbose
    if ($cert) {
        Write-Host "Certificate imported successfully."
        Write-Host "Thumbprint: $($cert.Thumbprint)"
    } else {
        Write-Warning "Import did not return a certificate object; check the certificate and try again."
    }
} catch {
    Write-Error "Failed to import certificate: $_"
    exit 1
}

Write-Host "Done. You may need to restart browsers to pick up the new trust."
