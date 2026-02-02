<#
switch-mode.ps1

Usage:
  # Dev mode (local)
  .\scripts\switch-mode.ps1 -Mode dev

  # Prod mode (requires Domain and Email)
  .\scripts\switch-mode.ps1 -Mode prod -Domain example.com -Email you@example.com

This script makes backups of `.env`, `docker-compose.yaml`, and Caddy autosave, updates values, and recreates containers safely.
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev','prod')]
    [string]$Mode,
    [string]$Domain,
    [string]$Email
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $root
$compose = Join-Path $root 'docker-compose.yaml'
$envFile = Join-Path $root '.env'
caddyAutosave = Join-Path $root 'caddy\config\caddy\autosave.json'
$ts = Get-Date -Format 'yyyyMMddHHmmss'

function Backup-IfExists($path){
    if (Test-Path $path) {
        $bak = "$path.$ts.bak"
        Copy-Item -Path $path -Destination $bak -Force
        Write-Output "Backed up $path -> $bak"
    } else { Write-Output "No file to backup: $path" }
}

Backup-IfExists $envFile
Backup-IfExists $compose
Backup-IfExists $caddyAutosave

# Helper to replace or add a line in file
function Replace-LineInFile($file, $pattern, $replacement){
    $content = Get-Content $file -Raw -ErrorAction Stop
    if ($content -match $pattern) {
        $new = $content -replace $pattern, $replacement
    } else {
        # append if not found
        $new = $content.TrimEnd() + "`n" + $replacement
    }
    Set-Content -Path $file -Value $new -Encoding UTF8
}

if ($Mode -eq 'dev') {
    Write-Output "Switching to DEV mode..."
    # Update .env
    Replace-LineInFile -file $envFile -pattern '^SEARXNG_HOSTNAME=.*' -replacement 'SEARXNG_HOSTNAME=localhost:8334'
    Replace-LineInFile -file $envFile -pattern '^LETSENCRYPT_EMAIL=.*' -replacement 'LETSENCRYPT_EMAIL='

    # Update docker-compose to use internal TLS and local base URL
    Replace-LineInFile -file $compose -pattern '^[ \t]*- SEARXNG_TLS=.*' -replacement '      - SEARXNG_TLS=internal'
    Replace-LineInFile -file $compose -pattern '^[ \t]*- SEARXNG_BASE_URL=.*' -replacement '      - SEARXNG_BASE_URL=http://${SEARXNG_HOSTNAME:-localhost:8334}/'

    Write-Output "Recreating caddy and searxng containers (dev)..."
    docker-compose -f "$compose" -p searxng-docker up -d --no-deps --force-recreate caddy searxng
    Write-Output "Done."
    exit 0
}

# Prod mode
if ($Mode -eq 'prod') {
    if (-not $Domain -or -not $Email) { Write-Error "Prod mode requires -Domain and -Email"; exit 1 }
    Write-Output "Switching to PROD mode for domain: $Domain"

    # Update .env
    Replace-LineInFile -file $envFile -pattern '^SEARXNG_HOSTNAME=.*' -replacement "SEARXNG_HOSTNAME=$Domain"
    Replace-LineInFile -file $envFile -pattern '^LETSENCRYPT_EMAIL=.*' -replacement "LETSENCRYPT_EMAIL=$Email"

    # Update docker-compose to allow ACME (use LETSENCRYPT_EMAIL) and HTTPS base URL
    Replace-LineInFile -file $compose -pattern '^[ \t]*- SEARXNG_TLS=.*' -replacement '      - SEARXNG_TLS=${LETSENCRYPT_EMAIL:-}'
    Replace-LineInFile -file $compose -pattern '^[ \t]*- SEARXNG_BASE_URL=.*' -replacement "      - SEARXNG_BASE_URL=https://${SEARXNG_HOSTNAME:-$Domain}/"

    # Remove Caddy autosave so Caddy reads Caddyfile and can request certs for domain
    if (Test-Path $caddyAutosave) {
        Rename-Item -Path $caddyAutosave -NewName "autosave.json.bak.$ts" -Force
        Write-Output "Renamed autosave to autosave.json.bak.$ts"
    }

    Write-Output "Recreating full stack (prod)..."
    docker-compose -f "$compose" -p searxng-docker down
    docker-compose -f "$compose" -p searxng-docker up -d
    Write-Output "Done."
    exit 0
}

Write-Error "Unknown mode. Use -Mode dev or -Mode prod."
exit 1
