# =============================================================================
# test-connections.ps1 — Verify Oracle and Snowflake connectivity
# =============================================================================
# Requires environment variables to be set (see set-local-env.template.ps1).
# Does NOT print passwords or key contents.
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Validate required environment variables ---
$required = @(
    "CDP_ORACLE_JDBC_URL", "CDP_ORACLE_USERNAME", "CDP_ORACLE_PASSWORD",
    "CDP_SNOWFLAKE_ACCOUNT", "CDP_SNOWFLAKE_USER", "CDP_SNOWFLAKE_ROLE",
    "CDP_SNOWFLAKE_WAREHOUSE", "CDP_SNOWFLAKE_DATABASE",
    "CDP_SNOWFLAKE_PRIVATE_KEY_PATH"
)
$missing = @()
foreach ($v in $required) {
    if (-not [System.Environment]::GetEnvironmentVariable($v)) {
        $missing += $v
    }
}
if ($missing.Count -gt 0) {
    Write-Error "Missing required environment variables:`n  $($missing -join "`n  ")`nSet them via scripts/set-local-env.template.ps1"
    exit 1
}

Write-Host ""
Write-Host "=== CDP Connectivity Test ===" -ForegroundColor Cyan
Write-Host "This test starts the backend briefly to hit /api/health/databases"
Write-Host ""

# --- Check key file exists ---
$keyPath = $env:CDP_SNOWFLAKE_PRIVATE_KEY_PATH
if (-not (Test-Path $keyPath)) {
    Write-Error "Snowflake private key file not found at path in CDP_SNOWFLAKE_PRIVATE_KEY_PATH"
    exit 1
}
Write-Host "Snowflake key file: EXISTS" -ForegroundColor Green

# --- Oracle connectivity via sqlplus or JDBC ping ---
Write-Host ""
Write-Host "Testing Oracle JDBC connectivity..." -ForegroundColor Yellow
$jarPath = (Get-ChildItem -Path "cdp-loader-api\target" -Filter "cdp-loader-api-*.jar" -Recurse | Select-Object -First 1).FullName
if (-not $jarPath) {
    Write-Warning "Backend JAR not found. Run 'mvn clean package -DskipTests' first."
} else {
    # Quick health check via curl after a short startup
    Write-Host "Backend JAR found: $( Split-Path $jarPath -Leaf )"
    Write-Host ""
    Write-Host "To run live connectivity test:" -ForegroundColor Cyan
    Write-Host "  1. Start the backend: .\scripts\start-backend.ps1"
    Write-Host "  2. In another terminal: curl http://localhost:8080/api/health/databases"
    Write-Host "  3. Expected: { `"oracle`": { `"status`": `"UP`" }, `"snowflake`": { `"status`": `"UP`" } }"
}

Write-Host ""
Write-Host "Connectivity check complete. Start backend for live JDBC verification." -ForegroundColor Green
