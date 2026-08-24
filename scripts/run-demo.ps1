# =============================================================================
# scripts/run-demo.ps1
# =============================================================================
# CDP Snowflake-Oracle Loader — Demo Walkthrough Script
# =============================================================================
# Drives the end-to-end demo sequence:
#   Step 0 — Verify environment variables are set
#   Step 1 — Health check (Oracle + Snowflake)
#   Step 2 — Run INITIAL_LOAD_JOB; poll until complete
#   Step 3 — Show reconciliation after initial load
#   Step 4 — Run DAILY_INCREMENTAL_JOB (post-script-12 changes); poll
#   Step 5 — Run MONTHLY_USAGE_JOB (post-script-13 data); poll
#   Step 6 — Show final reconciliation and error summary
#
# Prerequisites:
#   1. Oracle container running: scripts/start-oracle.ps1
#   2. Environment loaded:      . .\scripts\set-local-env.ps1
#   3. Backend running:         scripts/start-backend.ps1  (in separate terminal)
#   4. Snowflake scripts 12 and 13 already executed in Snowflake worksheets
#
# Usage:
#   . .\scripts\set-local-env.ps1
#   .\scripts\run-demo.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$BASE_URL = 'http://localhost:8080'
$POLL_INTERVAL_SEC = 4
$POLL_TIMEOUT_SEC  = 600   # 10 minutes max per job

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
function Write-Step { param([int]$n, [string]$msg)
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  STEP $n : $msg" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

function Write-OK   { param([string]$msg) Write-Host "[OK]  $msg" -ForegroundColor Green }
function Write-Fail { param([string]$msg) Write-Host "[ERR] $msg" -ForegroundColor Red }
function Write-Info { param([string]$msg) Write-Host "      $msg" }

function Invoke-Api {
    param([string]$Method, [string]$Path, [hashtable]$Body = $null)
    $uri = "$BASE_URL$Path"
    try {
        if ($Body) {
            $json = $Body | ConvertTo-Json
            return Invoke-RestMethod -Method $Method -Uri $uri `
                -ContentType 'application/json' -Body $json
        }
        return Invoke-RestMethod -Method $Method -Uri $uri
    } catch {
        $status = $_.Exception.Response?.StatusCode?.value__
        $detail = $_.ErrorDetails?.Message
        throw "HTTP $status on $Method $Path : $detail"
    }
}

function Wait-ForJob {
    param([string]$RunId, [string]$JobName)
    $elapsed = 0
    Write-Info "Polling run $RunId every ${POLL_INTERVAL_SEC}s (max ${POLL_TIMEOUT_SEC}s)..."
    while ($elapsed -lt $POLL_TIMEOUT_SEC) {
        Start-Sleep -Seconds $POLL_INTERVAL_SEC
        $elapsed += $POLL_INTERVAL_SEC
        try {
            $status = Invoke-Api GET "/api/jobs/history?page=0&size=20"
            $run = $status.content | Where-Object { $_.runId -eq $RunId } | Select-Object -First 1
            if ($run) {
                $s = $run.status
                Write-Info "  [$elapsed s] $JobName status: $s  reads=$($run.sourceRowsRead)  inserts=$($run.inserts)  updates=$($run.updates)  skips=$($run.skips)"
                if ($s -in @('COMPLETED','COMPLETED_WITH_ERRORS','FAILED','STOPPED','ABANDONED')) {
                    return $run
                }
            }
        } catch {
            Write-Info "  [$elapsed s] Poll error: $_"
        }
    }
    throw "Timeout waiting for run $RunId to complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 0 — Verify required environment variables
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 0 "Verify environment"
$required = @(
    'CDP_SNOWFLAKE_ACCOUNT','CDP_SNOWFLAKE_USER','CDP_SNOWFLAKE_ROLE',
    'CDP_SNOWFLAKE_WAREHOUSE','CDP_SNOWFLAKE_DATABASE','CDP_SNOWFLAKE_SCHEMA',
    'CDP_SNOWFLAKE_PRIVATE_KEY_PATH',
    'CDP_ORACLE_JDBC_URL','CDP_ORACLE_USERNAME','CDP_ORACLE_PASSWORD'
)
$missing = $required | Where-Object { -not (Get-Item "env:$_" -ErrorAction SilentlyContinue) }
if ($missing.Count -gt 0) {
    Write-Fail "Missing environment variables:"
    $missing | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Write-Host "Run:  . .\scripts\set-local-env.ps1" -ForegroundColor Yellow
    exit 1
}
Write-OK "All required environment variables are set"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — Health check
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 1 "Health check (Oracle + Snowflake)"
try {
    $health = Invoke-Api GET '/actuator/health'
    $oracleStatus    = $health.components?.db?.status ?? $health.status
    $snowflakeStatus = $health.components?.snowflake?.status ?? 'N/A'
    Write-OK "Backend is reachable"
    Write-Info "Oracle:    $oracleStatus"
    Write-Info "Snowflake: $snowflakeStatus"
} catch {
    Write-Fail "Backend health check failed: $_"
    Write-Host "Make sure the backend is running: .\scripts\start-backend.ps1" -ForegroundColor Yellow
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — Initial load
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 2 "INITIAL_LOAD_JOB"
Write-Info "Triggering initial load..."
try {
    $resp = Invoke-Api POST '/api/jobs/initial-load/trigger'
    $runId = $resp.runId
    Write-OK "Job accepted — runId=$runId  jobExecutionId=$($resp.jobExecutionId)"
} catch {
    if ($_ -match '409') {
        Write-Fail "Conflict: an initial load job is already running."
    } else {
        Write-Fail "Failed to trigger initial load: $_"
    }
    exit 1
}

$result = Wait-ForJob -RunId $runId -JobName 'INITIAL_LOAD_JOB'
if ($result.status -eq 'FAILED') {
    Write-Fail "Initial load FAILED — check GET /api/errors?runId=$runId"
    Write-Info "Error: $($result.errorMessage)"
    exit 1
}
Write-OK "Initial load $($result.status)"
Write-Info "  Source rows read : $($result.sourceRowsRead)"
Write-Info "  Inserts          : $($result.inserts)"
Write-Info "  Updates          : $($result.updates)"
Write-Info "  Skips            : $($result.skips)"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Reconciliation after initial load
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 3 "Reconciliation (post initial load)"
try {
    $recon = Invoke-Api GET '/api/dashboard/reconciliation'
    Write-OK "Reconciliation results:"
    $recon | ForEach-Object {
        Write-Info "  Entity: $($_.entityName)  src=$($_.sourceCount)  tgt=$($_.targetCount)  diff=$($_.countDiff)  status=$($_.reconStatus)"
    }
} catch {
    Write-Info "Reconciliation endpoint error: $_ (non-fatal)"
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Daily incremental load (after script 12)
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 4 "DAILY_INCREMENTAL_JOB (after Snowflake script 12)"
Write-Host ""
Write-Host "  PREREQUISITE: Snowflake script 12 (12-simulate-demo-daily-run.sql)" -ForegroundColor Yellow
Write-Host "  must have been executed in a Snowflake worksheet before continuing." -ForegroundColor Yellow
$confirm = Read-Host "  Has script 12 been run? [Y/n]"
if ($confirm -ne '' -and $confirm -notmatch '^[Yy]') {
    Write-Host "  Skipping daily incremental. Run script 12 in Snowflake and re-run this step." -ForegroundColor Yellow
} else {
    Write-Info "Triggering daily incremental load..."
    try {
        $resp2 = Invoke-Api POST '/api/jobs/daily-incremental/trigger'
        $runId2 = $resp2.runId
        Write-OK "Job accepted — runId=$runId2"
    } catch {
        Write-Fail "Failed to trigger daily incremental: $_"
        exit 1
    }
    $result2 = Wait-ForJob -RunId $runId2 -JobName 'DAILY_INCREMENTAL_JOB'
    Write-OK "Daily incremental $($result2.status)"
    Write-Info "  Source rows read : $($result2.sourceRowsRead)"
    Write-Info "  Inserts          : $($result2.inserts)"
    Write-Info "  Updates          : $($result2.updates)"
    Write-Info "  Skips            : $($result2.skips)"
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Monthly usage load (after script 13)
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 5 "MONTHLY_USAGE_JOB (after Snowflake script 13)"
Write-Host ""
Write-Host "  PREREQUISITE: Snowflake script 13 (13-simulate-demo-monthly-run.sql)" -ForegroundColor Yellow
Write-Host "  must have been executed in a Snowflake worksheet before continuing." -ForegroundColor Yellow
$confirm3 = Read-Host "  Has script 13 been run? [Y/n]"
if ($confirm3 -ne '' -and $confirm3 -notmatch '^[Yy]') {
    Write-Host "  Skipping monthly load. Run script 13 in Snowflake and re-run this step." -ForegroundColor Yellow
} else {
    Write-Info "Triggering monthly usage load..."
    try {
        $resp3 = Invoke-Api POST '/api/jobs/monthly-usage/trigger'
        $runId3 = $resp3.runId
        Write-OK "Job accepted — runId=$runId3"
    } catch {
        Write-Fail "Failed to trigger monthly usage load: $_"
        exit 1
    }
    $result3 = Wait-ForJob -RunId $runId3 -JobName 'MONTHLY_USAGE_JOB'
    Write-OK "Monthly usage job $($result3.status)"
    Write-Info "  Source rows read : $($result3.sourceRowsRead)"
    Write-Info "  Inserts          : $($result3.inserts)"
    Write-Info "  Updates          : $($result3.updates)"
    Write-Info "  Skips (rejects)  : $($result3.skips)"

    # Show intentional rejects
    Write-Info ""
    Write-Info "Checking intentional reject records (USG-INVK-*, USG-INVD-*)..."
    try {
        $errors = Invoke-Api GET "/api/errors?runId=$runId3&page=0&size=10"
        if ($errors.totalElements -gt 0) {
            Write-OK "$($errors.totalElements) error record(s) found in ETL_RECORD_ERROR:"
            $errors.content | ForEach-Object {
                Write-Info "  ID=$($_.sourceRecordId)  code=$($_.errorCode)  msg=$($_.errorMessage)"
            }
        } else {
            Write-Info "No error records found (intentional rejects may have been loaded in a prior run)"
        }
    } catch {
        Write-Info "Could not fetch error records: $_ (non-fatal)"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 — Final reconciliation summary
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 6 "Final reconciliation and job history summary"
try {
    $recon2 = Invoke-Api GET '/api/dashboard/reconciliation'
    Write-OK "Latest reconciliation:"
    $recon2 | ForEach-Object {
        $diff = $_.countDiff
        $color = if ($diff -eq 0) { 'Green' } else { 'Yellow' }
        Write-Host ("  {0,-25} src={1,6}  tgt={2,6}  diff={3,6}  [{4}]" -f `
            $_.entityName, $_.sourceCount, $_.targetCount, $diff, $_.reconStatus) `
            -ForegroundColor $color
    }
} catch {
    Write-Info "Reconciliation summary unavailable: $_ (non-fatal)"
}

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Green
Write-Host "  DEMO COMPLETE" -ForegroundColor Green
Write-Host "  Dashboard: http://localhost:5173" -ForegroundColor Green
Write-Host "  API docs:  http://localhost:8080/actuator" -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Green
