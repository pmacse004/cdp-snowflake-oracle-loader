# =============================================================================
# run-tests.ps1 — Run backend unit tests (no live credentials required)
# =============================================================================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== Running CDP Loader Unit Tests ===" -ForegroundColor Cyan
Write-Host "Tests run WITHOUT live Oracle or Snowflake connections."
Write-Host ""

Set-Location (Split-Path $PSScriptRoot -Parent)

# Run Maven unit tests (surefire, skipping integration tests)
Write-Host "Running: mvn clean test -pl cdp-loader-core,cdp-loader-api -DskipITs" -ForegroundColor Yellow
mvn clean test -pl cdp-loader-core,cdp-loader-api -DskipITs

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "All unit tests PASSED." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Some tests FAILED. Check surefire reports in target/surefire-reports/" -ForegroundColor Red
    exit 1
}

# Frontend build check
Write-Host ""
Write-Host "=== Running Frontend Build ===" -ForegroundColor Cyan
if (Test-Path "cdp-loader-ui") {
    Set-Location "cdp-loader-ui"
    if (-not (Test-Path "node_modules")) { npm install }
    npm run build
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Frontend build PASSED." -ForegroundColor Green
    } else {
        Write-Host "Frontend build FAILED." -ForegroundColor Red
        exit 1
    }
    Set-Location ..
}

Write-Host ""
Write-Host "All automated checks complete." -ForegroundColor Green
Write-Host ""
Write-Host "MANUAL/PENDING tests (require live credentials):" -ForegroundColor Yellow
Write-Host "  1. Live Snowflake connectivity: start backend, GET /api/health/databases"
Write-Host "  2. Live Oracle connectivity: confirm Flyway migrations match schema"
Write-Host "  3. Initial load end-to-end: POST /api/jobs/initial"
Write-Host "  4. Daily incremental load: run 12-simulate-demo-daily-run.sql, POST /api/jobs/daily"
Write-Host "  5. Monthly load + intentional rejections: run 13-simulate-demo-monthly-run.sql, POST /api/jobs/monthly"
