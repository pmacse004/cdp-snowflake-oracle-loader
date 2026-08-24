# =============================================================================
# Show Oracle container status and recent health-check history
# =============================================================================
# Usage:  .\scripts\oracle-status.ps1
# =============================================================================
Set-StrictMode -Version Latest

$container = "cdp-oracle-db"

Write-Host ""
Write-Host "=== Oracle Container Status ===" -ForegroundColor Cyan

$running = docker ps --filter "name=$container" --format "{{.Status}}" 2>$null
if ([string]::IsNullOrWhiteSpace($running)) {
    Write-Host "Container '$container' is NOT running." -ForegroundColor Yellow
    Write-Host "Start it with:  .\scripts\start-oracle.ps1 -WaitReady" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

Write-Host "Status : $running" -ForegroundColor Green

$health = docker inspect --format "{{.State.Health.Status}}" $container 2>$null
Write-Host "Health : $health"

Write-Host ""
Write-Host "=== TNS Listener (quick TCP test on port 1521) ===" -ForegroundColor Cyan
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect("localhost", 1521)
    $tcp.Close()
    Write-Host "Port 1521 is OPEN -- listener appears reachable." -ForegroundColor Green
} catch {
    Write-Host "Port 1521 is NOT reachable -- Oracle may still be starting." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Container resource usage ===" -ForegroundColor Cyan
docker stats $container --no-stream --format "CPU: {{.CPUPerc}}  MEM: {{.MemUsage}}" 2>$null

Write-Host ""
