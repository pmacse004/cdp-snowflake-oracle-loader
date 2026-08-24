# =============================================================================
# start-backend.ps1 — Start the CDP Loader Spring Boot backend
# =============================================================================
# Resolves SF_CLIENT_CONFIG_FILE to an absolute path before launch so that
# the Snowflake JDBC driver never attempts to locate sf_client_config.json
# from inside BOOT-INF/lib/ in the packaged fat JAR.
# =============================================================================
Set-StrictMode -Version Latest

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
    Write-Error "Missing required environment variables:`n  $($missing -join "`n  ")`nSource: . .\scripts\set-local-env.template.ps1 (after filling in your values)"
    exit 1
}

# --- Resolve SF_CLIENT_CONFIG_FILE to absolute path ---
# The Snowflake JDBC driver reads client_config_file from the JDBC URL.
# It must be an absolute filesystem path; a relative path resolves from the
# JAR working directory (BOOT-INF/lib/) which fails on Windows.
if (-not $env:SF_CLIENT_CONFIG_FILE) {
    $configRelative = "config\sf_client_config.json"
    $env:SF_CLIENT_CONFIG_FILE = (Resolve-Path $configRelative -ErrorAction Stop).Path
    Write-Host "SF_CLIENT_CONFIG_FILE resolved to: $env:SF_CLIENT_CONFIG_FILE" -ForegroundColor Cyan
} else {
    Write-Host "SF_CLIENT_CONFIG_FILE from environment: $env:SF_CLIENT_CONFIG_FILE" -ForegroundColor Cyan
}

if (-not (Test-Path $env:SF_CLIENT_CONFIG_FILE)) {
    Write-Error "SF_CLIENT_CONFIG_FILE does not exist: $env:SF_CLIENT_CONFIG_FILE`nExpected file: config\sf_client_config.json in the repository root."
    exit 1
}

# --- Preflight: Oracle port check ---
$oracleHost = "localhost"
$oraclePort = 1521
Write-Host "Checking Oracle is reachable at ${oracleHost}:${oraclePort}..." -ForegroundColor Cyan
$tcpClient = New-Object System.Net.Sockets.TcpClient
try {
    $tcpClient.Connect($oracleHost, $oraclePort)
    Write-Host "  Oracle port ${oraclePort}: OPEN" -ForegroundColor Green
} catch {
    Write-Error @"
Oracle is not reachable at ${oracleHost}:${oraclePort}.
Start the Oracle container first:
  docker start cdp-oracle-db
Then wait ~30 seconds for the listener to become healthy before retrying.
"@
    exit 1
} finally {
    $tcpClient.Close()
}

# --- Find the JAR ---
$jarPath = (Get-ChildItem -Path "cdp-loader-api\target" -Filter "cdp-loader-api-*.jar" |
            Where-Object { $_.Name -notlike '*original*' } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
if (-not $jarPath) {
    Write-Error "Backend JAR not found. Run first: mvn clean package -DskipTests"
    exit 1
}

Write-Host "Starting CDP Loader backend..." -ForegroundColor Cyan
Write-Host "JAR: $( Split-Path $jarPath -Leaf )"
Write-Host "Port: 8080"
Write-Host ""
Write-Host "Dashboard: http://localhost:5173"
Write-Host "API docs:  http://localhost:8080/swagger-ui.html"
Write-Host "Health:    http://localhost:8080/actuator/health"
Write-Host ""
Write-Host "Press Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

& java `
    --add-opens=java.base/java.nio=ALL-UNNAMED `
    -jar $jarPath
