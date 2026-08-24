# =============================================================================
# Tail Oracle container logs
# =============================================================================
# Usage:  .\scripts\oracle-logs.ps1
#         .\scripts\oracle-logs.ps1 -Lines 200
# =============================================================================
[CmdletBinding()]
param(
    [int]$Lines = 100
)

Set-StrictMode -Version Latest

Write-Host "Tailing last $Lines lines from cdp-oracle-db (Ctrl+C to stop)..." -ForegroundColor Cyan
docker logs --tail $Lines --follow cdp-oracle-db
