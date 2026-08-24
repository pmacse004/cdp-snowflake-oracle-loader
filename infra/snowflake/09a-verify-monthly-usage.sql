-- =============================================================================
-- Snowflake Read-Only Inventory — Step 9a: Post-Failure State of MONTHLY_USAGE
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE or CDP_LOADER_ROLE (SELECT only — no DML)
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   After the script 09 partial failure, this script reports exactly what
--   committed and what is still missing — without modifying any data.
--
-- WHAT COMMITTED BEFORE THE FAILURE
--   Snowflake DML statements commit independently (auto-commit per statement).
--   Section 1 (normal monthly usage ~932 rows) almost certainly committed.
--   Section 2a (boundary zero-KWH) failed because its USAGE_ID was too long.
--   Sections 3 (correction UPDATE) and 4 (invalid INSERTs) did not run.
--
-- SAFE RERUN
--   The corrected script 09 is idempotent:
--     Section 1: NOT EXISTS on (ENERGY_ACCOUNT_ID, BILLING_MONTH) — skips committed rows
--     Section 2a: NOT EXISTS on both business key AND compact USAGE_ID — inserts if missing
--     Section 3: UPDATED_AT recency guard + IS_CORRECTION=FALSE — skips already-corrected rows
--     Section 4: NOT EXISTS on (EA_ID, BILLING_MONTH) AND NOT EXISTS on compact USAGE_ID
--
-- PREREQUISITE
--   09-simulate-monthly-usage.sql must have been attempted (partial run).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PREFLIGHT — dual-role, read-only
-- ---------------------------------------------------------------------------
EXECUTE IMMEDIATE $$
DECLARE
    wrong_database EXCEPTION (
        -20001,
        'PREFLIGHT FAILED: expected database CDP_UTIL_DB'
    );
    wrong_role EXCEPTION (
        -20002,
        'PREFLIGHT FAILED: expected role CDP_ADMIN_ROLE or CDP_LOADER_ROLE'
    );
BEGIN
    IF (CURRENT_DATABASE() <> 'CDP_UTIL_DB') THEN
        RAISE wrong_database;
    END IF;
    IF (
        CURRENT_ROLE() <> 'CDP_ADMIN_ROLE'
        AND CURRENT_ROLE() <> 'CDP_LOADER_ROLE'
    ) THEN
        RAISE wrong_role;
    END IF;
    RETURN 'PREFLIGHT PASS: CDP_UTIL_DB / ' || CURRENT_ROLE();
END;
$$;

USE DATABASE CDP_UTIL_DB;
USE WAREHOUSE CDP_LOADER_WH;

-- $DEMO_AS_OF_DATE — must match script 09
SET DEMO_AS_OF_DATE       = TO_DATE('2026-06-01');
SET BILLING_MONTH_TARGET  = TO_CHAR(DATE_TRUNC('MONTH', $DEMO_AS_OF_DATE::DATE), 'YYYY-MM');

SELECT
    $DEMO_AS_OF_DATE      AS DEMO_ANCHOR_DATE,
    $BILLING_MONTH_TARGET AS TARGET_BILLING_MONTH;
-- Expected: 2026-06-01 | 2026-06

-- ===========================================================================
-- 1. Overall inventory for the target billing month
-- ===========================================================================
SELECT
    $BILLING_MONTH_TARGET                                               AS TARGET_MONTH,
    COUNT(*)                                                            AS TOTAL_ROWS,

    -- Normal rows: USG-EA-XXXXXX-YYYY-MM pattern
    SUM(CASE WHEN USAGE_ID NOT LIKE 'USG-BZ-%'
              AND USAGE_ID NOT LIKE 'USG-INVK-%'
              AND USAGE_ID NOT LIKE 'USG-INVD-%'
             THEN 1 ELSE 0 END)                                         AS NORMAL_ROWS,

    -- Boundary rows: USG-BZ-NNNNNN-YYYYMM
    SUM(CASE WHEN USAGE_ID LIKE 'USG-BZ-%'    THEN 1 ELSE 0 END)       AS BOUNDARY_ROWS,

    -- Invalid rows (expected to be rejected by Spring Batch):
    --   USG-INVK-NNNNNN-YYYYMM = negative KWH
    --   USG-INVD-NNNNNN-YYYYMM = inverted date order
    SUM(CASE WHEN USAGE_ID LIKE 'USG-INVK-%'  THEN 1 ELSE 0 END)       AS INVALID_NEG_KWH_ROWS,
    SUM(CASE WHEN USAGE_ID LIKE 'USG-INVD-%'  THEN 1 ELSE 0 END)       AS INVALID_DATE_ORD_ROWS,

    -- Correction rows (IS_CORRECTION = TRUE, any billing month)
    SUM(CASE WHEN IS_CORRECTION = TRUE
              AND BILLING_MONTH = $BILLING_MONTH_TARGET
             THEN 1 ELSE 0 END)                                         AS CORRECTION_ROWS_CURR_MONTH,

    -- Estimated reads
    SUM(CASE WHEN READ_TYPE = 'ESTIMATED'     THEN 1 ELSE 0 END)       AS ESTIMATED_READ_ROWS,

    -- KWH and billing totals (excluding intentional invalid records)
    ROUND(SUM(CASE WHEN USAGE_ID NOT LIKE 'USG-INVK-%'
                    AND USAGE_ID NOT LIKE 'USG-INVD-%'
               THEN KWH_USAGE ELSE 0 END), 2)                          AS TOTAL_KWH_VALID,
    ROUND(SUM(CASE WHEN USAGE_ID NOT LIKE 'USG-INVK-%'
                    AND USAGE_ID NOT LIKE 'USG-INVD-%'
               THEN TOTAL_BILLED ELSE 0 END), 2)                       AS TOTAL_BILLED_VALID

FROM BILLING.MONTHLY_USAGE
WHERE BILLING_MONTH = $BILLING_MONTH_TARGET;

-- ===========================================================================
-- 2. What committed vs what is missing
-- ===========================================================================

-- Section 1 status: normal rows
SELECT
    'SECTION-1' AS SECTION,
    'Normal monthly usage (~932 rows)' AS DESCRIPTION,
    COUNT(*) AS ROWS_PRESENT,
    CASE WHEN COUNT(*) >= 900 THEN 'COMMITTED_OK'
         WHEN COUNT(*) > 0    THEN 'PARTIAL'
         ELSE 'MISSING' END AS STATUS
FROM BILLING.MONTHLY_USAGE
WHERE BILLING_MONTH = $BILLING_MONTH_TARGET
  AND USAGE_ID NOT LIKE 'USG-BZ-%'
  AND USAGE_ID NOT LIKE 'USG-INVK-%'
  AND USAGE_ID NOT LIKE 'USG-INVD-%';

-- Section 2a status: boundary zero-KWH (USG-BZ-%)
SELECT
    'SECTION-2a' AS SECTION,
    'Boundary zero-KWH (USG-BZ-% prefix, 1 row expected)' AS DESCRIPTION,
    COUNT(*) AS ROWS_PRESENT,
    CASE WHEN COUNT(*) >= 1 THEN 'COMMITTED_OK'
         ELSE 'MISSING — needs insert on rerun' END AS STATUS
FROM BILLING.MONTHLY_USAGE
WHERE USAGE_ID LIKE 'USG-BZ-%'
  AND BILLING_MONTH = $BILLING_MONTH_TARGET;

-- Section 3 status: correction UPDATE (look for IS_CORRECTION=TRUE in prior month)
SELECT
    'SECTION-3' AS SECTION,
    'Correction rows (IS_CORRECTION=TRUE in prior billing month)' AS DESCRIPTION,
    COUNT(*) AS ROWS_PRESENT,
    CASE WHEN COUNT(*) >= 1 THEN 'COMMITTED_OK'
         ELSE 'MISSING — correction UPDATE needs to run' END AS STATUS
FROM BILLING.MONTHLY_USAGE
WHERE IS_CORRECTION = TRUE
  AND BILLING_MONTH = TO_CHAR(DATEADD(MONTH, -1, $DEMO_AS_OF_DATE::DATE), 'YYYY-MM');

-- Section 4 status: invalid records
SELECT
    'SECTION-4-INVK' AS SECTION,
    'Invalid negative-KWH (USG-INVK-% prefix, 1 row expected)' AS DESCRIPTION,
    COUNT(*) AS ROWS_PRESENT,
    CASE WHEN COUNT(*) >= 1 THEN 'COMMITTED_OK'
         ELSE 'MISSING — needs insert on rerun' END AS STATUS
FROM BILLING.MONTHLY_USAGE
WHERE USAGE_ID LIKE 'USG-INVK-%';

SELECT
    'SECTION-4-INVD' AS SECTION,
    'Invalid inverted-date (USG-INVD-% prefix, 1 row expected)' AS DESCRIPTION,
    COUNT(*) AS ROWS_PRESENT,
    CASE WHEN COUNT(*) >= 1 THEN 'COMMITTED_OK'
         ELSE 'MISSING — needs insert on rerun' END AS STATUS
FROM BILLING.MONTHLY_USAGE
WHERE USAGE_ID LIKE 'USG-INVD-%';

-- ===========================================================================
-- 3. Idempotency check: confirm no duplicate business keys exist
-- (UNIQUE constraint is (ENERGY_ACCOUNT_ID, BILLING_MONTH))
-- ===========================================================================
SELECT
    'BKEY-DUP' AS CHECK_ID,
    'No duplicate (ENERGY_ACCOUNT_ID, BILLING_MONTH) business keys' AS DESCRIPTION,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS,
    COUNT(*) AS DUPLICATE_PAIRS
FROM (
    SELECT ENERGY_ACCOUNT_ID, BILLING_MONTH, COUNT(*) AS CNT
    FROM BILLING.MONTHLY_USAGE
    GROUP BY ENERGY_ACCOUNT_ID, BILLING_MONTH
    HAVING COUNT(*) > 1
);
-- Expected: PASS, 0 duplicate pairs.
-- The invalid records use different ENERGY_ACCOUNT_IDs via the LIMIT 1 filter
-- and do NOT share a business key with the corresponding normal row.

-- ===========================================================================
-- 4. Sample of normal rows to confirm format
-- ===========================================================================
SELECT USAGE_ID, ENERGY_ACCOUNT_ID, BILLING_MONTH, KWH_USAGE, TOTAL_BILLED, READ_TYPE
FROM BILLING.MONTHLY_USAGE
WHERE BILLING_MONTH  = $BILLING_MONTH_TARGET
  AND USAGE_ID NOT LIKE 'USG-BZ-%'
  AND USAGE_ID NOT LIKE 'USG-INVK-%'
  AND USAGE_ID NOT LIKE 'USG-INVD-%'
ORDER BY USAGE_ID
LIMIT 5;
-- Review: USAGE_ID should look like USG-EA-001136-2026-06 (max 23 chars, within VARCHAR(30))

-- ===========================================================================
-- 5. USAGE_ID length check on all rows
-- ===========================================================================
SELECT
    'ID-LEN' AS CHECK_ID,
    'All USAGE_IDs are within VARCHAR(30)' AS DESCRIPTION,
    MAX(LENGTH(USAGE_ID)) AS MAX_ID_LENGTH,
    CASE WHEN MAX(LENGTH(USAGE_ID)) <= 30 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM BILLING.MONTHLY_USAGE
WHERE BILLING_MONTH = $BILLING_MONTH_TARGET;
-- Expected: MAX_ID_LENGTH <= 30, STATUS = PASS
