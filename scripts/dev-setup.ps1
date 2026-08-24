# =============================================================================
# Developer setup script -- CDP Snowflake Oracle Loader
# =============================================================================
# Run this ONCE after cloning the repository on a new Windows developer machine.
# Checks prerequisites, copies templates, prints next-step checklist.
#
# Usage:  .\scripts\dev-setup.ps1
# =============================================================================
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$root = Split-Path $PSScriptRoot -Parent
$allOk = $true

function Test-Prerequisite {
    param(
        [string]$Label,
        [scriptblock]$Test,
        [string]$Fix
    )
    $result = $false
    try { $result = & $Test } catch { $result = $false }
    if ($result) {
        Write-Host "  [OK]   $Label" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Label" -ForegroundColor Red
        Write-Host "         Fix: $Fix" -ForegroundColor Yellow
        $script:allOk = $false
    }
}

Write-Host ""
Write-Host "CDP Snowflake Oracle Loader -- Developer Setup Check" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Prerequisites
# ---------------------------------------------------------------------------
Write-Host "1. Prerequisites" -ForegroundColor White

Test-Prerequisite "Java 17+" {
    $v = java -version 2>&1 | Select-String "version"
    $v -match '"(17|21|22|23|24)'
} "Install JDK 17+: winget install --id EclipseAdoptium.Temurin.17.JDK"

Test-Prerequisite "Maven 3.9+" {
    $v = mvn --version 2>&1
    $v -match "Apache Maven 3\.[9]"
} "Install Maven: winget install --id Apache.Maven"

Test-Prerequisite "Docker CLI" {
    docker --version 2>&1 | Out-Null
    $LASTEXITCODE -eq 0
} "Install Docker Desktop from https://www.docker.com/products/docker-desktop/"

Test-Prerequisite "Docker daemon" {
    docker info 2>&1 | Out-Null
    $LASTEXITCODE -eq 0
} "Start Docker Desktop"

Test-Prerequisite "Node.js 20+" {
    $v = node --version 2>&1
    $v -match "v2[0-9]"
} "Install Node.js 20+: winget install --id OpenJS.NodeJS.LTS"

Test-Prerequisite "OpenSSL" {
    $v = openssl version 2>&1
    $v -match "OpenSSL"
} "OpenSSL not found. Install via Git for Windows or: winget install ShiningLight.OpenSSL.Light"

Write-Host ""

# ---------------------------------------------------------------------------
# 2. Template files
# ---------------------------------------------------------------------------
Write-Host "2. Copying template files (skips if destination already exists)" -ForegroundColor White

$templates = @(
    @{
        src  = "$root\infra\docker\.env.template"
        dest = "$root\infra\docker\.env"
        note = "Set ORACLE_PWD to a strong password before starting Oracle"
    },
    @{
        src  = "$root\cdp-loader-api\src\main\resources\application-local.yml.template"
        dest = "$root\cdp-loader-api\src\main\resources\application-local.yml"
        note = "Fill in Oracle password and Snowflake private key path"
    }
)

foreach ($t in $templates) {
    if (Test-Path $t.dest) {
        Write-Host "  [SKIP] $(Split-Path $t.dest -Leaf) already exists" -ForegroundColor Gray
    } else {
        Copy-Item $t.src $t.dest
        Write-Host "  [COPY] $(Split-Path $t.dest -Leaf) created" -ForegroundColor Green
        Write-Host "         Action needed: $($t.note)" -ForegroundColor Yellow
    }
}

Write-Host ""

# ---------------------------------------------------------------------------
# 3. RSA key pair check
# ---------------------------------------------------------------------------
Write-Host "3. Snowflake RSA key pair" -ForegroundColor White

$keyDir  = Join-Path $env:USERPROFILE ".cdp-loader\keys"
$keyFile = Join-Path $keyDir "snowflake_rsa_key.p8"

if (Test-Path $keyFile) {
    Write-Host "  [OK]   Private key found: $keyFile" -ForegroundColor Green
} else {
    Write-Host "  [TODO] No private key found at: $keyFile" -ForegroundColor Yellow
    Write-Host "         Run: .\infra\snowflake\keygen.ps1" -ForegroundColor Yellow
    Write-Host "         Then paste the public key into infra\snowflake\02-create-service-user.sql" -ForegroundColor Yellow
}

Write-Host ""

# ---------------------------------------------------------------------------
# 4. Summary
# ---------------------------------------------------------------------------
Write-Host "=====================================================" -ForegroundColor Cyan
if ($allOk) {
    Write-Host "All prerequisite checks passed." -ForegroundColor Green
} else {
    Write-Host "Some checks failed -- address the items above before proceeding." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Edit infra\docker\.env                 (set ORACLE_PWD)" -ForegroundColor Gray
Write-Host "  2. Edit application-local.yml              (set Oracle + Snowflake values)" -ForegroundColor Gray
Write-Host "  3. .\scripts\start-oracle.ps1 -WaitReady  (start Oracle)" -ForegroundColor Gray
Write-Host "  4. Run: infra\oracle\00-dba-bootstrap.sql  (connect as SYSDBA)" -ForegroundColor Gray
Write-Host "  5. .\infra\snowflake\keygen.ps1            (generate RSA key pair)" -ForegroundColor Gray
Write-Host "  6. Run Snowflake scripts 01-04 in order as documented" -ForegroundColor Gray
Write-Host "  7. mvn clean package -DskipTests           (build the application)" -ForegroundColor Gray
Write-Host "  8. mvn spring-boot:run -pl cdp-loader-api -Dspring-boot.run.profiles=local" -ForegroundColor Gray
Write-Host ""
