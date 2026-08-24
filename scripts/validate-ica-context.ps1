# =============================================================================
# scripts/validate-ica-context.ps1
# =============================================================================
# CDP Snowflake-Oracle Loader -- ICA/MCP Context Package Validation
# =============================================================================
# Checks that all required ICA context artifacts exist, are non-empty,
# and have the correct structure (basic YAML/JSON validity).
#
# Does NOT require live Oracle or Snowflake connections.
#
# Usage:
#   .\scripts\validate-ica-context.ps1
# =============================================================================

$ErrorActionPreference = 'Continue'
$CONTEXT_DIR = Join-Path $PSScriptRoot '..\ica-mcp-context'
$CONTEXT_DIR = (Resolve-Path $CONTEXT_DIR).Path

$pass  = 0
$fail  = 0
$total = 0

function Write-Pass { param([string]$msg) Write-Host "[PASS] $msg" -ForegroundColor Green;  $script:pass++;  $script:total++ }
function Write-Fail { param([string]$msg) Write-Host "[FAIL] $msg" -ForegroundColor Red;    $script:fail++;  $script:total++ }
function Write-Info { param([string]$msg) Write-Host "       $msg" }

Write-Host ""
Write-Host "ICA/MCP Context Package Validation" -ForegroundColor Cyan
Write-Host "Context directory: $CONTEXT_DIR"
Write-Host ("-" * 70)

# ---------------------------------------------------------------------------
# 1. Required files exist and are non-empty
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "1. File existence and non-empty checks" -ForegroundColor Yellow

$requiredFiles = @(
    'manifest.yaml',
    'business-glossary.yaml',
    'source-schema.yaml',
    'target-schema.yaml',
    'entity-mappings.yaml',
    'column-mappings.yaml',
    'join-rules.yaml',
    'transformation-rules.yaml',
    'validation-rules.yaml',
    'reference-code-rules.yaml',
    'incremental-watermark-rules.yaml',
    'initial-load-rules.yaml',
    'daily-load-rules.yaml',
    'monthly-load-rules.yaml',
    'error-handling-rules.yaml',
    'reconciliation-rules.yaml',
    'security-classification.yaml',
    'nonfunctional-requirements.yaml',
    'tenant-adapter-template.yaml',
    'context-index.json'
)

foreach ($f in $requiredFiles) {
    $path = Join-Path $CONTEXT_DIR $f
    if (-not (Test-Path $path)) {
        Write-Fail "MISSING: $f"
    } elseif ((Get-Item $path).Length -eq 0) {
        Write-Fail "EMPTY:   $f"
    } else {
        $kb = [Math]::Round((Get-Item $path).Length / 1KB, 1)
        Write-Pass "EXISTS:  $f  ($kb KB)"
    }
}

# ---------------------------------------------------------------------------
# 2. context-index.json is valid JSON and lists correct artifact count
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "2. context-index.json structure" -ForegroundColor Yellow

$indexPath = Join-Path $CONTEXT_DIR 'context-index.json'
if (Test-Path $indexPath) {
    try {
        $index = Get-Content $indexPath -Raw | ConvertFrom-Json
        $artifactCount = $index.artifacts.Count
        if ($artifactCount -ge 19) {
            Write-Pass "context-index.json parses as valid JSON; $artifactCount artifact(s) listed"
        } else {
            Write-Fail "context-index.json has only $artifactCount artifacts (expected >= 19)"
        }
        $missingRefs = 0
        foreach ($artifact in $index.artifacts) {
            $aPath = Join-Path $CONTEXT_DIR $artifact.file
            if (-not (Test-Path $aPath)) {
                Write-Fail "context-index.json references missing file: $($artifact.file)"
                $missingRefs++
            }
        }
        if ($missingRefs -eq 0) {
            Write-Pass "All files referenced in context-index.json are present"
        }
    } catch {
        Write-Fail "context-index.json is not valid JSON: $_"
    }
}

# ---------------------------------------------------------------------------
# 3. YAML files contain required top-level keys
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "3. YAML top-level key checks (version + context_package)" -ForegroundColor Yellow

$yamlFiles = $requiredFiles | Where-Object { $_ -like '*.yaml' }
foreach ($f in $yamlFiles) {
    $path = Join-Path $CONTEXT_DIR $f
    if (Test-Path $path) {
        $content = Get-Content $path -Raw
        $hasVersion = $content -match 'version:\s*"'
        $hasPackage = $content -match 'context_package:\s*cdp-snowflake-oracle-loader'
        if ($hasVersion -and $hasPackage) {
            Write-Pass "$f has version + context_package"
        } elseif (-not $hasVersion) {
            Write-Fail "$f missing 'version' key"
        } else {
            Write-Fail "$f missing 'context_package: cdp-snowflake-oracle-loader'"
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Security checks -- no real credentials in context files
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "4. Security pattern scan (no real credentials)" -ForegroundColor Yellow

$secretPatterns = @(
    @{ Name = 'Snowflake account literal';   Pattern = 'LJPNAFI-RW79936' },
    @{ Name = 'Private key PEM header';      Pattern = '-----BEGIN PRIVATE KEY-----' },
    @{ Name = 'Private key PEM header RSA';  Pattern = '-----BEGIN RSA PRIVATE KEY-----' }
)

$contextFiles = Get-ChildItem $CONTEXT_DIR -File
$secretFound = $false
foreach ($file in $contextFiles) {
    $content = Get-Content $file.FullName -Raw
    foreach ($sp in $secretPatterns) {
        if ($content -match $sp.Pattern) {
            Write-Fail "$($file.Name) contains '$($sp.Name)' pattern"
            $secretFound = $true
        }
    }
}
if (-not $secretFound) {
    Write-Pass "No credential patterns found in context package files"
}

# ---------------------------------------------------------------------------
# 5. column-mappings.yaml entity coverage
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "5. column-mappings.yaml entity coverage" -ForegroundColor Yellow

$cmPath = Join-Path $CONTEXT_DIR 'column-mappings.yaml'
if (Test-Path $cmPath) {
    $cm = Get-Content $cmPath -Raw
    $entities = @('customer_mappings','energy_account_mappings','billing_account_mappings',
                  'premise_mappings','meter_mappings','monthly_usage_mappings')
    foreach ($e in $entities) {
        if ($cm -match $e) {
            Write-Pass "column-mappings.yaml contains: $e"
        } else {
            Write-Fail "column-mappings.yaml MISSING: $e"
        }
    }
}

# ---------------------------------------------------------------------------
# 6. Validation-rules.yaml intentional reject codes
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "6. validation-rules.yaml intentional reject codes" -ForegroundColor Yellow

$vrPath = Join-Path $CONTEXT_DIR 'validation-rules.yaml'
if (Test-Path $vrPath) {
    $vr = Get-Content $vrPath -Raw
    $intentionalCodes = @('VAL_USAGE_NEGATIVE_KWH','VAL_USAGE_DATE_RANGE')
    foreach ($code in $intentionalCodes) {
        if ($vr -match $code) {
            Write-Pass "validation-rules.yaml has intentional reject code: $code"
        } else {
            Write-Fail "validation-rules.yaml MISSING intentional reject code: $code"
        }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host ("-" * 70)
if ($fail -eq 0) {
    $color = 'Green'
} else {
    $color = 'Red'
}
Write-Host "  TOTAL: $total checks   PASS: $pass   FAIL: $fail" -ForegroundColor $color
Write-Host ("-" * 70)

if ($fail -gt 0) {
    Write-Host ""
    Write-Host "Context package has $fail failure(s). Resolve before importing into ICA/MCP." -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "Context package validation PASSED. Safe to import into ICA/MCP." -ForegroundColor Green
    exit 0
}
