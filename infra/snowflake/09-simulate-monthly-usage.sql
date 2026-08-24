-- =============================================================================
-- Snowflake Data Generation — Step 9: Simulate Monthly Usage
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Generate monthly usage and billing records for the CURRENT billing month
--   across ~1,000 active energy accounts.  Includes:
--     - Normal actual reads (majority)
--     - Estimated reads (~10%)
--     - Corrected records (3 — simulate billing corrections)
--     - Boundary cases (zero KWH)
--     - Controlled invalid records (2 — for error-handling demonstration)
--
-- USAGE_ID FORMAT AND COLUMN SIZE
--   USAGE_ID is VARCHAR(30) in both Snowflake and Oracle.
--   All generated IDs must stay within 30 characters.
--
--   Normal rows:    'USG-' || EA-ID || '-' || YYYYMM
--                   e.g. USG-EA-001136-202606  (22 chars max — safe)
--                   EA-ID max = 'EA-D1-00050' = 11 chars → total = 4+11+1+6 = 22 ✓
--
--   Compact scenario IDs (no verbose English in USAGE_ID — use CORRECTION_REASON):
--
--     USG-BZ-NNNNNN-YYYYMM    Boundary: zero-KWH record           (22 chars max)
--     USG-INVK-NNNNNN-YYYYMM  Invalid: negative KWH (VR-USAGE-005)(24 chars max)
--     USG-INVD-NNNNNN-YYYYMM  Invalid: inverted dates (VR-USAGE-003)(24 chars max)
--
--   Where NNNNNN = last 6 digits of the energy account sequence number.
--   Full scenario identity is recorded in CORRECTION_REASON, not in USAGE_ID.
--
-- SIMULATION RUN TRACKING (Issue #12)
--   Boundary and invalid records carry in CORRECTION_REASON:
--     SIM_RUN_ID (stable run identifier)
--     SCENARIO code
--     Violation description
--   These fields allow test assertions to be stable across reruns.
--
-- BUSINESS KEY
--   (ENERGY_ACCOUNT_ID, BILLING_MONTH) — enforced by UNIQUE constraint.
--   This script targets accounts NOT already in the current billing month
--   to prevent duplicate key errors.
--
-- DEMO_AS_OF_DATE (Issue #9)
--   $DEMO_AS_OF_DATE must be set (script 05 sets it).
--   Billing month is derived from $DEMO_AS_OF_DATE, not CURRENT_DATE(), so
--   the billing month is stable across reruns.
--
-- IDEMPOTENCY
--   Deterministic cohort algorithm (corrected — see root-cause note below):
--   1. Rank ALL eligible accounts by HASH(EA_ID || SIM_RUN_ID) mod a large prime.
--      This rank is stable and independent of which rows are already in the table.
--   2. Take the first 932 by that rank — this is the NAMED COHORT for SIM_RUN_ID.
--   3. Only then apply NOT EXISTS to skip already-loaded cohort members.
--
--   ROOT CAUSE of previous non-idempotent behaviour:
--   The original eligible CTE applied NOT EXISTS BEFORE ROW_NUMBER/LIMIT.
--   On a rerun after partial failure, the NOT EXISTS excluded already-loaded rows,
--   ROW_NUMBER() then renumbered the remaining pool, and LIMIT 932 selected a
--   completely different set -- doubling the normal rows to 1,864.
--   The corrected algorithm fixes the rank on the full eligible universe first.
--
--   Boundary and invalid record INSERTs still check NOT EXISTS on USAGE_ID.
--   UPDATE (correction) checks UPDATED_AT + IS_CORRECTION = FALSE guard.
--
-- EXECUTE AFTER
--   06-generate-initial-data.sql (must have run)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PREFLIGHT — aborts immediately on wrong database or role
-- ---------------------------------------------------------------------------
EXECUTE IMMEDIATE $$
DECLARE
    wrong_database EXCEPTION (
        -20001,
        'PREFLIGHT FAILED: expected database CDP_UTIL_DB'
    );
    wrong_role EXCEPTION (
        -20002,
        'PREFLIGHT FAILED: expected role CDP_ADMIN_ROLE'
    );
BEGIN
    IF (CURRENT_DATABASE() <> 'CDP_UTIL_DB') THEN
        RAISE wrong_database;
    END IF;
    IF (CURRENT_ROLE() <> 'CDP_ADMIN_ROLE') THEN
        RAISE wrong_role;
    END IF;
    RETURN 'PREFLIGHT PASS: CDP_UTIL_DB / CDP_ADMIN_ROLE';
END;
$$;

USE ROLE CDP_ADMIN_ROLE;
USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- ---------------------------------------------------------------------------
-- DEMO_AS_OF_DATE — fixed demo anchor date (standalone, no prior session needed)
-- ---------------------------------------------------------------------------
-- *** OPERATOR PARAMETER — must match the value used in scripts 05–10 ***
-- Used for billing business dates (BILLING_MONTH, BILL_START_DATE, BILL_END_DATE).
-- CREATED_AT and UPDATED_AT use CURRENT_TIMESTAMP() — real technical timestamps.
-- ---------------------------------------------------------------------------
SET DEMO_AS_OF_DATE = TO_DATE('2026-06-01');

-- Simulation run ID — stable identifier for this batch
SET SIM_RUN_ID = '09-MONTHLY-SIM-001';

-- Derive billing month variables from DEMO_AS_OF_DATE
-- DEMO_AS_OF_DATE is always the 1st of a month; DATE_TRUNC is a no-op but kept for clarity.
SET BILLING_MONTH_TARGET = TO_CHAR(DATE_TRUNC('MONTH', $DEMO_AS_OF_DATE::DATE), 'YYYY-MM');
SET BILL_START = DATE_TRUNC('MONTH', $DEMO_AS_OF_DATE::DATE);
SET BILL_END   = DATEADD(DAY, -1, DATEADD(MONTH, 1, DATE_TRUNC('MONTH', $DEMO_AS_OF_DATE::DATE)));

SELECT
    $DEMO_AS_OF_DATE      AS DEMO_ANCHOR_DATE,
    $BILLING_MONTH_TARGET AS TARGET_BILLING_MONTH,
    $BILL_START           AS BILL_START_DATE,
    $BILL_END             AS BILL_END_DATE,
    $SIM_RUN_ID           AS SIMULATION_RUN_ID;
-- Expected output: 2026-06-01 | 2026-06 | 2026-06-01 | 2026-06-30 | 09-MONTHLY-SIM-001

-- Confirm initial data exists (script 06 must have run)
EXECUTE IMMEDIATE $$
DECLARE
    insufficient_active_accounts EXCEPTION (
        -20005,
        'DATA PREREQ FAILED: fewer than 1000 active energy accounts — run 06-generate-initial-data.sql first'
    );
    ea_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO :ea_count
    FROM CUSTOMER.ENERGY_ACCOUNT
    WHERE ACCOUNT_STATUS = 'ACTIVE';
    IF (ea_count < 1000) THEN
        RAISE insufficient_active_accounts;
    END IF;
    RETURN 'Active energy accounts present — ' || ea_count;
END;
$$;

-- ---------------------------------------------------------------------------
-- Pre-insert USAGE_ID length validation
-- Confirms that the BILLING_MONTH_TARGET session variable combined with a
-- representative EA-ID does not exceed 30 characters before any inserts run.
-- If this check fails, do not proceed.
-- ---------------------------------------------------------------------------
SELECT
    'USG-ID-LEN-CHECK' AS CHECK_ID,
    -- Longest normal USAGE_ID uses the longest possible EA-ID in this dataset.
    -- Initial-load IDs: EA-000001 (9 chars). Daily-batch IDs: EA-D1-00050 (11 chars).
    -- Worst case normal: 'USG-' + 'EA-D1-00050' + '-' + 'YYYY-MM' = 4+11+1+7 = 23 chars ✓
    -- Worst case compact: 'USG-INVD-' + '001136' + '-' + '202606' = 9+6+1+6 = 22 chars ✓
    -- BILLING_MONTH_TARGET is YYYY-MM (7 chars); compact suffix strips '-' → YYYYMM (6 chars).
    LENGTH('USG-EA-D1-00050-' || $BILLING_MONTH_TARGET)     AS NORMAL_MAX_LEN,
    LENGTH('USG-INVD-001136-' || REPLACE($BILLING_MONTH_TARGET, '-', '')) AS COMPACT_MAX_LEN,
    CASE
        WHEN LENGTH('USG-EA-D1-00050-' || $BILLING_MONTH_TARGET)                          > 30 THEN 'FAIL: normal ID too long'
        WHEN LENGTH('USG-INVD-001136-' || REPLACE($BILLING_MONTH_TARGET, '-', ''))        > 30 THEN 'FAIL: compact ID too long'
        ELSE 'PASS: all USAGE_ID patterns within VARCHAR(30)'
    END AS STATUS;
-- Expected: NORMAL_MAX_LEN=23, COMPACT_MAX_LEN=22, STATUS=PASS
-- If STATUS shows FAIL, stop and investigate BILLING_MONTH_TARGET before inserting.

-- ============================================================
-- Section 1: Normal monthly usage (~932 rows)
-- Targets active accounts not yet loaded for this billing month
-- ============================================================
USE SCHEMA BILLING;

INSERT INTO MONTHLY_USAGE (
    USAGE_ID, ENERGY_ACCOUNT_ID, PREMISE_ID, METER_ID,
    BILLING_MONTH, BILL_START_DATE, BILL_END_DATE, BILLING_DAYS,
    KWH_USAGE, KWH_ADJUSTED, PEAK_DEMAND_KW,
    PREV_METER_READING, CURR_METER_READING,
    READ_TYPE, RATE_PLAN,
    FIXED_CHARGE, ENERGY_CHARGE, DEMAND_CHARGE,
    SUBTOTAL_CHARGE, TAX_AMOUNT, TOTAL_BILLED,
    IS_CORRECTION, CORRECTION_REASON,
    CREATED_AT, UPDATED_AT
)
WITH all_eligible AS (
    -- STEP 1: Rank the FULL eligible universe by a hash that is stable regardless
    -- of what is already in the MONTHLY_USAGE table.
    -- Using HASH(EA_ID || 'SIM:<SIM_RUN_ID>') mod a large prime ensures the rank
    -- is the same on every run, whether or not some rows are already loaded.
    SELECT
        ea.ENERGY_ACCOUNT_ID,
        ea.RATE_CLASS,
        p.PREMISE_ID,
        m.METER_ID,
        MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SIM:' || $SIM_RUN_ID)), 9999991) AS COHORT_RANK
    FROM CUSTOMER.ENERGY_ACCOUNT ea
    JOIN SERVICE.PREMISE p  ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID AND p.END_DATE IS NULL
    JOIN SERVICE.METER   m  ON m.PREMISE_ID        = p.PREMISE_ID         AND m.IS_ACTIVE = TRUE
    WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
),
named_cohort AS (
    -- STEP 2: The named cohort is always the same 932 accounts, determined by rank.
    -- This is the authoritative cohort for SIM_RUN_ID = $SIM_RUN_ID.
    -- It does NOT depend on the current contents of MONTHLY_USAGE.
    SELECT *
    FROM all_eligible
    QUALIFY ROW_NUMBER() OVER (ORDER BY COHORT_RANK) <= 932
),
to_insert AS (
    -- STEP 3: Skip cohort members already loaded for this billing month.
    -- NOT EXISTS is applied here, AFTER the cohort is fixed.
    -- On any rerun, only cohort members not yet present can be inserted.
    SELECT *
    FROM named_cohort nc
    WHERE NOT EXISTS (
        SELECT 1 FROM BILLING.MONTHLY_USAGE u
        WHERE u.ENERGY_ACCOUNT_ID = nc.ENERGY_ACCOUNT_ID
          AND u.BILLING_MONTH     = $BILLING_MONTH_TARGET
    )
),
rate_data AS (
    -- Rate parameters from ATTRIBUTES VARIANT, not from CODE_LABEL
    SELECT
        CODE AS RATE_PLAN_CODE,
        TRY_TO_DECIMAL(ATTRIBUTES['fixed']::STRING,  10, 2) AS FIXED_RATE,
        TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6) AS ENERGY_RATE,
        TRY_TO_DECIMAL(ATTRIBUTES['demand']::STRING, 10, 6) AS DEMAND_RATE,
        TRY_TO_DECIMAL(ATTRIBUTES['tax']::STRING,    10, 6) AS TAX_RATE
    FROM REF.CODE_VALUE
    WHERE DOMAIN = 'RATE_PLAN' AND IS_ACTIVE = TRUE
),
account_rate AS (
    SELECT e.*,
        CASE e.RATE_CLASS
            WHEN 'LARGE_INDUSTRIAL'  THEN CASE WHEN MOD(ABS(HASH(e.ENERGY_ACCOUNT_ID)), 2)=0 THEN 'IND-1' ELSE 'IND-2' END
            WHEN 'MEDIUM_COMMERCIAL' THEN CASE WHEN MOD(ABS(HASH(e.ENERGY_ACCOUNT_ID)), 2)=0 THEN 'COM-1' ELSE 'COM-2' END
            WHEN 'SMALL_COMMERCIAL'  THEN 'COM-3'
            WHEN 'SOLAR_NET'         THEN 'SOL-1'
            WHEN 'RESIDENTIAL'       THEN CASE MOD(ABS(HASH(e.ENERGY_ACCOUNT_ID)),3) WHEN 0 THEN 'RES-1' WHEN 1 THEN 'RES-2' ELSE 'RES-3' END
            ELSE 'RES-1'
        END AS RATE_PLAN
    FROM to_insert e
)
SELECT
    -- Normal USAGE_ID: 'USG-' + EA-ID + '-' + 'YYYY-MM'
    -- Max length: 4 + 11 (EA-D1-00050) + 1 + 7 = 23 chars — within VARCHAR(30)
    'USG-' || ar.ENERGY_ACCOUNT_ID || '-' || $BILLING_MONTH_TARGET AS USAGE_ID,
    ar.ENERGY_ACCOUNT_ID,
    ar.PREMISE_ID,
    ar.METER_ID,
    $BILLING_MONTH_TARGET  AS BILLING_MONTH,
    $BILL_START::DATE      AS BILL_START_DATE,
    $BILL_END::DATE        AS BILL_END_DATE,
    DATEDIFF(DAY, $BILL_START::DATE, $BILL_END::DATE) + 1 AS BILLING_DAYS,

    -- KWH usage
    ROUND(CASE ar.RATE_CLASS
        WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 100000)
        WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 10000)
        WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 3000)
        WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 400)
        ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 1800)
    END::NUMBER(12,3), 3) AS KWH_USAGE,

    ROUND((CASE ar.RATE_CLASS
        WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 100000)
        WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 10000)
        WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 3000)
        WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 400)
        ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 1800)
    END) * 1.002::NUMBER(12,3), 3) AS KWH_ADJUSTED,

    CASE WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL')
         THEN ROUND((CASE ar.RATE_CLASS WHEN 'LARGE_INDUSTRIAL'
                    THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 400)
                    ELSE 10  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 90) END)::NUMBER(10,3), 3)
         ELSE NULL END AS PEAK_DEMAND_KW,

    ROUND(MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'PR9')), 99000)::NUMBER(12,3), 3) AS PREV_METER_READING,
    ROUND((MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'PR9')), 99000)
          + CASE ar.RATE_CLASS
                WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 100000)
                WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 10000)
                WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 3000)
                WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 400)
                ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 1800)
              END)::NUMBER(12,3), 3) AS CURR_METER_READING,

    -- ~10% estimated reads
    CASE WHEN MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'RT9')), 10) < 9 THEN 'ACTUAL' ELSE 'ESTIMATED' END AS READ_TYPE,
    ar.RATE_PLAN,

    rd.FIXED_RATE AS FIXED_CHARGE,
    ROUND(CASE ar.RATE_CLASS
        WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 100000)
        WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 10000)
        WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 3000)
        WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 400)
        ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 1800)
    END * rd.ENERGY_RATE, 2) AS ENERGY_CHARGE,

    CASE WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL') AND rd.DEMAND_RATE IS NOT NULL
         THEN ROUND(CASE ar.RATE_CLASS WHEN 'LARGE_INDUSTRIAL'
                    THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 400)
                    ELSE 10  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 90) END * rd.DEMAND_RATE, 2)
         ELSE 0.00 END AS DEMAND_CHARGE,

    -- Subtotal
    ROUND(rd.FIXED_RATE
        + ROUND(CASE ar.RATE_CLASS
            WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 100000)
            WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 10000)
            WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 3000)
            WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 400)
            ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 1800)
          END * rd.ENERGY_RATE, 2)
        + CASE WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL') AND rd.DEMAND_RATE IS NOT NULL
               THEN ROUND(CASE ar.RATE_CLASS WHEN 'LARGE_INDUSTRIAL'
                           THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 400)
                           ELSE 10  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 90) END * rd.DEMAND_RATE, 2)
               ELSE 0.00 END
    , 2) AS SUBTOTAL_CHARGE,

    -- Tax (applied to subtotal)
    ROUND(
        ROUND(rd.FIXED_RATE
            + ROUND(CASE ar.RATE_CLASS
                WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 100000)
                WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 10000)
                WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 3000)
                WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 400)
                ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 1800)
              END * rd.ENERGY_RATE, 2)
            + CASE WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL') AND rd.DEMAND_RATE IS NOT NULL
                   THEN ROUND(CASE ar.RATE_CLASS WHEN 'LARGE_INDUSTRIAL'
                               THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 400)
                               ELSE 10  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 90) END * rd.DEMAND_RATE, 2)
                   ELSE 0.00 END
        , 2) * rd.TAX_RATE
    , 2) AS TAX_AMOUNT,

    -- Total billed = subtotal + tax
    ROUND(
        ROUND(rd.FIXED_RATE
            + ROUND(CASE ar.RATE_CLASS
                WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 100000)
                WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 10000)
                WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 3000)
                WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 400)
                ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 1800)
              END * rd.ENERGY_RATE, 2)
            + CASE WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL') AND rd.DEMAND_RATE IS NOT NULL
                   THEN ROUND(CASE ar.RATE_CLASS WHEN 'LARGE_INDUSTRIAL'
                               THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 400)
                               ELSE 10  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 90) END * rd.DEMAND_RATE, 2)
                   ELSE 0.00 END
        , 2)
        + ROUND(
            ROUND(rd.FIXED_RATE
                + ROUND(CASE ar.RATE_CLASS
                    WHEN 'LARGE_INDUSTRIAL'  THEN 50000 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 100000)
                    WHEN 'MEDIUM_COMMERCIAL' THEN 5000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 10000)
                    WHEN 'SMALL_COMMERCIAL'  THEN 1000  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 3000)
                    WHEN 'SOLAR_NET'         THEN 200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 400)
                    ELSE                          200   + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'M9')), 1800)
                  END * rd.ENERGY_RATE, 2)
                + CASE WHEN ar.RATE_CLASS IN ('LARGE_INDUSTRIAL','MEDIUM_COMMERCIAL') AND rd.DEMAND_RATE IS NOT NULL
                       THEN ROUND(CASE ar.RATE_CLASS WHEN 'LARGE_INDUSTRIAL'
                                   THEN 100 + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 400)
                                   ELSE 10  + MOD(ABS(HASH(ar.ENERGY_ACCOUNT_ID || 'KW9')), 90) END * rd.DEMAND_RATE, 2)
                       ELSE 0.00 END
            , 2) * rd.TAX_RATE
        , 2)
    , 2) AS TOTAL_BILLED,

    FALSE AS IS_CORRECTION,
    NULL  AS CORRECTION_REASON,
    CURRENT_TIMESTAMP() AS CREATED_AT,
    CURRENT_TIMESTAMP() AS UPDATED_AT

FROM account_rate ar
JOIN rate_data rd ON rd.RATE_PLAN_CODE = ar.RATE_PLAN;

-- ============================================================
-- Section 2: Boundary cases
-- ============================================================

-- USAGE_ID scheme for boundary and invalid records:
--   Compact prefix  + 6-digit seq + '-' + YYYYMM (no '-' in month suffix)
--
--   USG-BZ-NNNNNN-YYYYMM   Boundary zero-KWH           max 22 chars ✓
--   USG-INVK-NNNNNN-YYYYMM Invalid negative-KWH         max 24 chars ✓
--   USG-INVD-NNNNNN-YYYYMM Invalid inverted-date-order  max 24 chars ✓
--
--   NNNNNN = last 6 digits of the EA sequence number extracted from EA-ID.
--   Full scenario identity lives in CORRECTION_REASON, not USAGE_ID.
--   All three patterns fit within VARCHAR(30).

-- 2a: Zero-KWH record (USG-BZ-NNNNNN-YYYYMM, max 22 chars)
--     Represents a vacant residential account with no consumption this period.
--     Fixed charge still applies.
--     CORRECTION_REASON carries the scenario code and SIM_RUN_ID for traceability.
INSERT INTO BILLING.MONTHLY_USAGE (
    USAGE_ID, ENERGY_ACCOUNT_ID, PREMISE_ID, METER_ID,
    BILLING_MONTH, BILL_START_DATE, BILL_END_DATE, BILLING_DAYS,
    KWH_USAGE, KWH_ADJUSTED, PEAK_DEMAND_KW,
    PREV_METER_READING, CURR_METER_READING,
    READ_TYPE, RATE_PLAN,
    FIXED_CHARGE, ENERGY_CHARGE, DEMAND_CHARGE,
    SUBTOTAL_CHARGE, TAX_AMOUNT, TOTAL_BILLED,
    IS_CORRECTION, CORRECTION_REASON, CREATED_AT, UPDATED_AT
)
SELECT
    -- USG-BZ- + last 6 of EA seq + '-' + YYYYMM  (no hyphen in month — keeps length ≤ 22)
    'USG-BZ-' || RIGHT(ea.ENERGY_ACCOUNT_ID, 6) || '-' || REPLACE($BILLING_MONTH_TARGET, '-', ''),
    ea.ENERGY_ACCOUNT_ID, p.PREMISE_ID, m.METER_ID,
    $BILLING_MONTH_TARGET, $BILL_START::DATE, $BILL_END::DATE,
    DATEDIFF(DAY, $BILL_START::DATE, $BILL_END::DATE) + 1,
    0.000, 0.000, NULL, 1000.000, 1000.000,
    'ACTUAL', 'RES-1', 8.50, 0.00, 0.00, 8.50, ROUND(8.50*0.08,2), ROUND(8.50 + ROUND(8.50*0.08,2),2),
    FALSE,
    'SIM:' || $SIM_RUN_ID || '|SCENARIO:BOUNDARY_ZERO_KWH|VACANT_ACCOUNT_NO_CONSUMPTION',
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM CUSTOMER.ENERGY_ACCOUNT ea
JOIN SERVICE.PREMISE p ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID AND p.END_DATE IS NULL
JOIN SERVICE.METER   m ON m.PREMISE_ID = p.PREMISE_ID AND m.IS_ACTIVE = TRUE
WHERE ea.ACCOUNT_STATUS = 'ACTIVE' AND ea.RATE_CLASS = 'RESIDENTIAL'
  AND NOT EXISTS (SELECT 1 FROM BILLING.MONTHLY_USAGE u
                  WHERE u.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
                    AND u.BILLING_MONTH = $BILLING_MONTH_TARGET)
  AND NOT EXISTS (SELECT 1 FROM BILLING.MONTHLY_USAGE u
                  WHERE u.USAGE_ID = 'USG-BZ-' || RIGHT(ea.ENERGY_ACCOUNT_ID, 6)
                                   || '-' || REPLACE($BILLING_MONTH_TARGET, '-', ''))
LIMIT 1;

-- ============================================================
-- Section 3: Correction / versioned records (3 rows)
-- Update 3 existing month-ago records to simulate bill corrections
-- Uses a newer UPDATED_AT so the incremental processor sees them as updates
-- ============================================================
UPDATE BILLING.MONTHLY_USAGE
SET
    KWH_USAGE         = KWH_USAGE * 0.98,         -- 2% correction
    KWH_ADJUSTED      = KWH_USAGE * 0.98,
    IS_CORRECTION     = TRUE,
    -- SIM_RUN_ID embedded for traceability (Issue #12)
    CORRECTION_REASON = 'SIM:' || $SIM_RUN_ID || '|SCENARIO:CORRECTION|METER_REREAD_CORRECTION',
    UPDATED_AT        = CURRENT_TIMESTAMP()
WHERE BILLING_MONTH = TO_CHAR(DATEADD(MONTH, -1, $DEMO_AS_OF_DATE::DATE), 'YYYY-MM')
  AND MOD(ABS(HASH(USAGE_ID || 'COR')), 3500) = 0
  AND IS_CORRECTION = FALSE
  AND UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP());
-- Expected: ~3 rows updated

-- ============================================================
-- Section 4: Controlled invalid records (Issue #11 / #12)
-- 2 rows deliberately violating business rules to exercise Spring Batch
-- rejection logic.  Inserted with compact USAGE_ID prefixes:
--   USG-INVK-NNNNNN-YYYYMM  (negative KWH)
--   USG-INVD-NNNNNN-YYYYMM  (inverted date order)
-- Scripts 07 and 10 use these prefixes to distinguish them from valid records.
--
-- These records are EXPECTED_INVALID — the ETL load must reject them into
-- ETL_RECORD_ERROR, NOT load them into the target Oracle tables.
--
-- Each record carries in CORRECTION_REASON:
--   SIM_RUN_ID (prefix 'SIM:09-MONTHLY-SIM-001|')
--   Scenario code
--   Violation description
-- USAGE_ID uses compact prefixes (USG-INVK-%, USG-INVD-%) — NOT verbose names.
-- ============================================================

-- Invalid 1: Negative KWH — USG-INVK-NNNNNN-YYYYMM (max 24 chars)
-- Scenario FAIL_NEG_KWH (VR-USAGE-005)
-- Expected outcome: Spring Batch validator rejects into ETL_RECORD_ERROR.
-- Full scenario identity in CORRECTION_REASON; USAGE_ID stays compact.
INSERT INTO BILLING.MONTHLY_USAGE (
    USAGE_ID, ENERGY_ACCOUNT_ID, PREMISE_ID, METER_ID,
    BILLING_MONTH, BILL_START_DATE, BILL_END_DATE, BILLING_DAYS,
    KWH_USAGE, KWH_ADJUSTED, PEAK_DEMAND_KW,
    PREV_METER_READING, CURR_METER_READING,
    READ_TYPE, RATE_PLAN,
    FIXED_CHARGE, ENERGY_CHARGE, DEMAND_CHARGE,
    SUBTOTAL_CHARGE, TAX_AMOUNT, TOTAL_BILLED,
    IS_CORRECTION, CORRECTION_REASON, CREATED_AT, UPDATED_AT
)
SELECT
    -- USG-INVK- + last 6 of EA seq + '-' + YYYYMM  (max 24 chars, within VARCHAR(30))
    'USG-INVK-' || RIGHT(ea.ENERGY_ACCOUNT_ID, 6) || '-' || REPLACE($BILLING_MONTH_TARGET, '-', ''),
    ea.ENERGY_ACCOUNT_ID, p.PREMISE_ID, m.METER_ID,
    $BILLING_MONTH_TARGET, $BILL_START::DATE, $BILL_END::DATE,
    DATEDIFF(DAY, $BILL_START::DATE, $BILL_END::DATE) + 1,
    -50.000, -50.000, NULL, 5000.000, 4950.000,
    'ACTUAL', 'RES-1', 8.50, -5.75, 0.00, 2.75, 0.22, 2.97,
    FALSE,
    -- SIM_RUN_ID | SCENARIO | VIOLATION_DESCRIPTION (full detail here, not in USAGE_ID)
    'SIM:' || $SIM_RUN_ID || '|SCENARIO:FAIL_NEG_KWH|INTENTIONAL_TEST_NEGATIVE_KWH',
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM CUSTOMER.ENERGY_ACCOUNT ea
JOIN SERVICE.PREMISE p ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID AND p.END_DATE IS NULL
JOIN SERVICE.METER   m ON m.PREMISE_ID = p.PREMISE_ID AND m.IS_ACTIVE = TRUE
WHERE ea.ACCOUNT_STATUS = 'ACTIVE' AND ea.RATE_CLASS = 'RESIDENTIAL'
  AND NOT EXISTS (SELECT 1 FROM BILLING.MONTHLY_USAGE u
                  WHERE u.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
                    AND u.BILLING_MONTH = $BILLING_MONTH_TARGET)
  AND NOT EXISTS (SELECT 1 FROM BILLING.MONTHLY_USAGE u
                  WHERE u.USAGE_ID = 'USG-INVK-' || RIGHT(ea.ENERGY_ACCOUNT_ID, 6)
                                   || '-' || REPLACE($BILLING_MONTH_TARGET, '-', ''))
LIMIT 1;

-- Invalid 2: Inverted billing period — USG-INVD-NNNNNN-YYYYMM (max 24 chars)
-- Scenario FAIL_DATE_ORDER (VR-USAGE-003)
-- Expected outcome: Spring Batch validator rejects into ETL_RECORD_ERROR.
INSERT INTO BILLING.MONTHLY_USAGE (
    USAGE_ID, ENERGY_ACCOUNT_ID, PREMISE_ID, METER_ID,
    BILLING_MONTH, BILL_START_DATE, BILL_END_DATE, BILLING_DAYS,
    KWH_USAGE, PEAK_DEMAND_KW,
    PREV_METER_READING, CURR_METER_READING,
    READ_TYPE, RATE_PLAN,
    FIXED_CHARGE, ENERGY_CHARGE, DEMAND_CHARGE,
    SUBTOTAL_CHARGE, TAX_AMOUNT, TOTAL_BILLED,
    IS_CORRECTION, CORRECTION_REASON, CREATED_AT, UPDATED_AT
)
SELECT
    -- USG-INVD- + last 6 of EA seq + '-' + YYYYMM  (max 24 chars, within VARCHAR(30))
    'USG-INVD-' || RIGHT(ea.ENERGY_ACCOUNT_ID, 6) || '-' || REPLACE($BILLING_MONTH_TARGET, '-', ''),
    ea.ENERGY_ACCOUNT_ID, p.PREMISE_ID, m.METER_ID,
    $BILLING_MONTH_TARGET,
    $BILL_END::DATE,    -- intentionally swapped: END before START — invalid date order
    $BILL_START::DATE,
    -1,                 -- negative billing days — invalid
    500.000, NULL, 10000.000, 10500.000,
    'ACTUAL', 'RES-2', 8.50, 45.00, 0.00, 53.50, 4.28, 57.78,
    FALSE,
    -- SIM_RUN_ID | SCENARIO | VIOLATION_DESCRIPTION (full detail here, not in USAGE_ID)
    'SIM:' || $SIM_RUN_ID || '|SCENARIO:FAIL_DATE_ORDER|INTENTIONAL_TEST_DATE_ORDER',
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM CUSTOMER.ENERGY_ACCOUNT ea
JOIN SERVICE.PREMISE p ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID AND p.END_DATE IS NULL
JOIN SERVICE.METER   m ON m.PREMISE_ID = p.PREMISE_ID AND m.IS_ACTIVE = TRUE
WHERE ea.ACCOUNT_STATUS = 'ACTIVE' AND ea.RATE_CLASS = 'RESIDENTIAL'
  AND NOT EXISTS (SELECT 1 FROM BILLING.MONTHLY_USAGE u
                  WHERE u.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
                    AND u.BILLING_MONTH = $BILLING_MONTH_TARGET)
  AND NOT EXISTS (SELECT 1 FROM BILLING.MONTHLY_USAGE u
                  WHERE u.USAGE_ID = 'USG-INVD-' || RIGHT(ea.ENERGY_ACCOUNT_ID, 6)
                                   || '-' || REPLACE($BILLING_MONTH_TARGET, '-', ''))
LIMIT 1;

-- ============================================================
-- Summary of current billing month
-- USAGE_ID prefix legend (updated compact codes):
--   USG-<EA-ID>-YYYY-MM  Normal rows (Section 1)
--   USG-BZ-NNNNNN-YYYYMM Boundary zero-KWH (Section 2a)
--   USG-INVK-NNNNNN-YYYYMM Invalid negative-KWH (Section 4, Invalid 1)
--   USG-INVD-NNNNNN-YYYYMM Invalid inverted-date (Section 4, Invalid 2)
-- ============================================================
SELECT
    $BILLING_MONTH_TARGET                                               AS TARGET_MONTH,
    COUNT(*)                                                            AS TOTAL_ROWS,
    SUM(CASE WHEN USAGE_ID LIKE 'USG-INVK-%'
              OR USAGE_ID LIKE 'USG-INVD-%'    THEN 1 ELSE 0 END)      AS INVALID_ROWS,
    SUM(CASE WHEN USAGE_ID LIKE 'USG-BZ-%'     THEN 1 ELSE 0 END)      AS BOUNDARY_ROWS,
    SUM(CASE WHEN IS_CORRECTION = TRUE         THEN 1 ELSE 0 END)      AS CORRECTION_ROWS,
    SUM(CASE WHEN READ_TYPE = 'ESTIMATED'      THEN 1 ELSE 0 END)      AS ESTIMATED_ROWS,
    ROUND(SUM(CASE WHEN USAGE_ID NOT LIKE 'USG-INVK-%'
                    AND USAGE_ID NOT LIKE 'USG-INVD-%'
               THEN KWH_USAGE ELSE 0 END), 2)                          AS TOTAL_KWH_VALID,
    ROUND(SUM(CASE WHEN USAGE_ID NOT LIKE 'USG-INVK-%'
                    AND USAGE_ID NOT LIKE 'USG-INVD-%'
               THEN TOTAL_BILLED ELSE 0 END), 2)                       AS TOTAL_BILLED_VALID
FROM BILLING.MONTHLY_USAGE
WHERE BILLING_MONTH = $BILLING_MONTH_TARGET;
