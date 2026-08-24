# =============================================================================
# Stop Oracle Database Free 23c Docker container
# =============================================================================
# Usage:  .\scripts\stop-oracle.ps1
#         .\scripts\stop-oracle.ps1 -RemoveVolume    (DESTROYS all data!)
# =============================================================================
[CmdletBinding()]
param(
    [switch]$RemoveVolume
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ComposeFile = Join-Path $PSScriptRoot "..\infra\docker\docker-compose.yml"

if ($RemoveVolume) {
    Write-Host "WARNING: -RemoveVolume will permanently delete all Oracle data." -ForegroundColor Red
    $confirm = Read-Host "Type YES to confirm"
    if ($confirm -ne "YES") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "Stopping and removing Oracle container and volume..." -ForegroundColor Cyan
    docker compose --file $ComposeFile down --volumes
} else {
    Write-Host "Stopping Oracle container (data volume preserved)..." -ForegroundColor Cyan
    docker compose --file $ComposeFile down
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Done." -ForegroundColor Green
} else {
    Write-Host "docker compose down exited with code $LASTEXITCODE." -ForegroundColor Yellow
}
