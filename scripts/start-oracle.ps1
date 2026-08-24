# =============================================================================
# Start Oracle Database Free 23c in Docker
# =============================================================================
# Usage:  .\scripts\start-oracle.ps1
#         .\scripts\start-oracle.ps1 -WaitReady
#         .\scripts\start-oracle.ps1 -WaitReady -TimeoutSeconds 300
# =============================================================================
[CmdletBinding()]
param(
    [switch]$WaitReady,
    [int]$TimeoutSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ComposeFile = Join-Path $PSScriptRoot "..\infra\docker\docker-compose.yml"
$EnvFile     = Join-Path $PSScriptRoot "..\infra\docker\.env"

# ---------------------------------------------------------------------------
# Guard: .env must exist
# ---------------------------------------------------------------------------
if (-not (Test-Path $EnvFile)) {
    Write-Host ""
    Write-Host "ERROR: infra\docker\.env not found." -ForegroundColor Red
    Write-Host "  Copy infra\docker\.env.template to infra\docker\.env" -ForegroundColor Yellow
    Write-Host "  and set ORACLE_PWD to a strong password before starting." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# ---------------------------------------------------------------------------
# Start (or resume) the Oracle container
# ---------------------------------------------------------------------------
Write-Host "Starting Oracle Database Free 23c..." -ForegroundColor Cyan
docker compose --file $ComposeFile --env-file $EnvFile up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "docker compose up failed (exit $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Container started. First-run initialisation may take 60-120 s." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Optional: wait until healthy
# ---------------------------------------------------------------------------
if ($WaitReady) {
    Write-Host "Waiting for Oracle health check (timeout ${TimeoutSeconds}s)..." -ForegroundColor Cyan
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $healthy  = $false

    while ((Get-Date) -lt $deadline) {
        $status = docker inspect --format "{{.State.Health.Status}}" cdp-oracle-db 2>$null
        if ($status -eq "healthy") {
            $healthy = $true
            break
        }
        Write-Host "  Health: $status -- waiting..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 10
    }

    if ($healthy) {
        Write-Host "Oracle is healthy and ready." -ForegroundColor Green
    } else {
        Write-Host "Timed out waiting for Oracle to become healthy." -ForegroundColor Yellow
        Write-Host "Run .\scripts\oracle-status.ps1 to check current state." -ForegroundColor Yellow
        exit 2
    }
}
