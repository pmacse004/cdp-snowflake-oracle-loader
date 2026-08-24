# =============================================================================
# Generate an RSA key pair for Snowflake key-pair authentication
# =============================================================================
# Usage:  .\infra\snowflake\keygen.ps1
#         .\infra\snowflake\keygen.ps1 -OutputDir "C:\keys\cdp-loader"
#
# Output (written to -OutputDir, default: %USERPROFILE%\.cdp-loader\keys):
#   snowflake_rsa_key.p8       -- PKCS#8 private key (NEVER commit this)
#   snowflake_rsa_key.pub      -- public key (safe to share / paste into SQL)
#
# Prerequisites: OpenSSL must be on PATH.
#   Bundled with Git for Windows: C:\Program Files\Git\usr\bin\openssl.exe
#   Or install: winget install --id ShiningLight.OpenSSL.Light
# =============================================================================
[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path $env:USERPROFILE ".cdp-loader\keys")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Locate OpenSSL
# ---------------------------------------------------------------------------
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $openssl) {
    $gitOpenssl = "C:\Program Files\Git\usr\bin\openssl.exe"
    if (Test-Path $gitOpenssl) {
        $openssl = $gitOpenssl
    } else {
        Write-Error "openssl not found on PATH. Install it or add Git\usr\bin to PATH."
        exit 1
    }
} else {
    $openssl = $openssl.Source
}
Write-Host "Using OpenSSL: $openssl" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Create output directory (restricted permissions)
# ---------------------------------------------------------------------------
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $acl = Get-Acl $OutputDir
    $acl.SetAccessRuleProtection($true, $false)
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $currentUser,
        "FullControl",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )
    $acl.AddAccessRule($rule)
    Set-Acl $OutputDir $acl
}

$privateKeyPath = Join-Path $OutputDir "snowflake_rsa_key.p8"
$publicKeyPath  = Join-Path $OutputDir "snowflake_rsa_key.pub"

Write-Host "Output directory : $OutputDir" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1: Generate 2048-bit RSA private key (PKCS#8, unencrypted)
# ---------------------------------------------------------------------------
Write-Host "Generating 2048-bit RSA private key..." -ForegroundColor Cyan
& $openssl genrsa 2048 | & $openssl pkcs8 -topk8 -nocrypt -out $privateKeyPath

if ($LASTEXITCODE -ne 0) {
    Write-Error "Private key generation failed."
    exit $LASTEXITCODE
}
Write-Host "Private key written: $privateKeyPath" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 2: Extract public key
# ---------------------------------------------------------------------------
Write-Host "Extracting public key..." -ForegroundColor Cyan
& $openssl rsa -in $privateKeyPath -pubout -out $publicKeyPath

if ($LASTEXITCODE -ne 0) {
    Write-Error "Public key extraction failed."
    exit $LASTEXITCODE
}
Write-Host "Public key  written: $publicKeyPath" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 3: Display public key content for pasting into Snowflake SQL
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Public key content ===" -ForegroundColor Yellow
Write-Host "(Paste into infra/snowflake/02-create-service-user.sql)" -ForegroundColor Gray
Write-Host "(Remove the -----BEGIN/END PUBLIC KEY----- header and footer lines)" -ForegroundColor Gray
Write-Host ""
Get-Content $publicKeyPath
Write-Host ""
Write-Host "IMPORTANT: Keep the private key file PRIVATE." -ForegroundColor Red
Write-Host "           Never commit it to source control." -ForegroundColor Red
Write-Host "           Add its FILE PATH (not the key) to application-local.yml." -ForegroundColor Red
