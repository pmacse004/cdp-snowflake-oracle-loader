-- =============================================================================
-- CDP Snowflake to Oracle Data Loader
-- Audit and Repair: Monthly Cohort Idempotency Defect
-- Step 09b — READ-ONLY dry-run (no DELETE executed without operator action)
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Diagnose the non-idempotent cohort-selection defect introduced when
--   script 09 was rerun after a partial failure.
--
-- ROOT CAUSE
--   Script 09 (Section 1) selected normal monthly rows using:
--
--     eligible CTE: filters accounts NOT YET in BILLING_MONTH_TARGET
--     account_rate CTE: ROW_NUMBER() OVER (ORDER BY ENERGY_ACCOUNT_ID) and WHERE RN <= 932
--
--   On the FIRST run (partial failure at boundary inserts):
--     ~932 rows were inserted for accounts ranked 1..932 of the eligible universe.
--
--   On the SECOND full run:
--     The NOT EXISTS filter excluded the 932 already-loaded accounts.
--     ROW_NUMBER() then numbered the REMAINING eligible accounts 1..N.
--     WHERE RN <= 932 selected the NEXT 932 — a completely different cohort.
--     No business-key duplicates were created (UNIQUE constraint blocked them),
--     but the table now holds 1,864 normal rows instead of 932.
--
-- CORRECT ALGORITHM (now implemented in 09-simulate-monthly-usage.sql)
--   1. Rank ALL eligible accounts by a deterministic hash independent of
--      insertion state:
--         MOD(ABS(HASH(ENERGY_ACCOUNT_ID || 'SIM:09-MONTHLY-SIM-001')), 9999991)
--      This rank is always the same set regardless of what is already loaded.
--   2. Take the first 932 by that rank — this is the NAMED COHORT for SIM:09-MONTHLY-SIM-001.
--   3. Only then apply NOT EXISTS to skip already-loaded members of that cohort.
--   This guarantees: on any rerun, only rows from the named cohort can be inserted,
--   and each row is inserted exactly once.
--
-- CLEANUP APPROACH
--   The accidental second cohort (rows NOT in the named cohort) must be removed.
--   Rows from the named cohort that were loaded on the first run are preserved.
--   The boundary row (USG-BZ-%), correction rows, and invalid rows (USG-INVK-%,
--   USG-INVD-%) are preserved regardless of cohort membership.
--
-- OPERATOR INSTRUCTIONS
--   1. Run this entire script.  It contains ONLY SELECT statements and comments.
--   2. Review every result set before any deletion.
--   3. Scroll to the "PROPOSED REPAIR" section near the bottom.
--   4. Uncomment the DELETE statement ONLY after you have verified:
--        a. intended_cohort count = 932
--        b. accidental_cohort count = 932
--        c. outside_cohort count = same as accidental_cohort count
--        d. boundary, invalid and correction rows have 0 overlap with outside_cohort
--   5. After uncommenting, run the DELETE in a transaction, review the row count,
--      then COMMIT or ROLLBACK.
--
-- SAFE TO RERUN WITHOUT MODIFICATION — THIS SCRIPT CONTAINS NO ACTIVE DML.
--   All DELETE statements are commented out.
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

-- Demo anchor date — must match scripts 05–10
SET DEMO_AS_OF_DATE      = TO_DATE('2026-06-01');
SET BILLING_MONTH_TARGET = TO_CHAR(DATE_TRUNC('MONTH', $DEMO_AS_OF_DATE::DATE), 'YYYY-MM');
SET SIM_RUN_ID           = '09-MONTHLY-SIM-001';

SELECT
    $DEMO_AS_OF_DATE      AS DEMO_ANCHOR_DATE,
    $BILLING_MONTH_TARGET AS TARGET_BILLING_MONTH,
    $SIM_RUN_ID           AS SIMULATION_RUN_ID;

-- =============================================================================
-- SECTION 1: OVERALL COUNTS IN MONTHLY_USAGE FOR TARGET BILLING MONTH
-- =============================================================================
SELECT
    '1_OVERALL_COUNTS'                                        AS SECTION,
    COUNT(*)                                                   AS TOTAL_ROWS_IN_TARGET_MONTH,
    SUM(CASE WHEN USAGE_ID NOT LIKE 'USG-BZ-%'
              AND USAGE_ID NOT LIKE 'USG-INVK-%'
              AND USAGE_ID NOT LIKE 'USG-INVD-%'
             THEN 1 ELSE 0 END)                               AS NORMAL_ROWS,
    SUM(CASE WHEN USAGE_ID LIKE 'USG-BZ-%'   THEN 1 ELSE 0 END) AS BOUNDARY_ROWS,
    SUM(CASE WHEN USAGE_ID LIKE 'USG-INVK-%' THEN 1 ELSE 0 END) AS INVALID_NEG_KWH_ROWS,
    SUM(CASE WHEN USAGE_ID LIKE 'USG-INVD-%' THEN 1 ELSE 0 END) AS INVALID_DATE_ORDER_ROWS,
    SUM(CASE WHEN IS_CORRECTION = TRUE       THEN 1 ELSE 0 END) AS CORRECTION_ROWS
FROM BILLING.MONTHLY_USAGE
WHERE BILLING_MONTH = $BILLING_MONTH_TARGET;
-- EXPECTED AFTER DEFECT:
--   TOTAL_ROWS_IN_TARGET_MONTH = 1,867 (1,864 normal + 1 boundary + 2 invalid)
--   NORMAL_ROWS = 1,864 (should be 932 — defect doubled the normal cohort)
--   BOUNDARY_ROWS = 1
--   INVALID_NEG_KWH_ROWS = 1
--   INVALID_DATE_ORDER_ROWS = 1

-- =============================================================================
-- SECTION 2: INTENDED DETERMINISTIC COHORT (932 rows)
-- These are the accounts that should exist in MONTHLY_USAGE after repair.
-- The rank is computed from the hash of EA_ID + SIM_RUN_ID, making it
-- independent of insertion order and stable across all reruns.
-- =============================================================================
SELECT
    '2_INTENDED_COHORT_DEFINITION'                            AS SECTION,
    COUNT(*)                                                   AS INTENDED_COHORT_SIZE,
    MIN(COHORT_RANK)                                           AS MIN_RANK,
    MAX(COHORT_RANK)                                           AS MAX_RANK
FROM (
    SELECT
        ea.ENERGY_ACCOUNT_ID,
        MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SIM:' || $SIM_RUN_ID)), 9999991) AS COHORT_RANK
    FROM CUSTOMER.ENERGY_ACCOUNT ea
    JOIN SERVICE.PREMISE p
         ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
        AND p.END_DATE IS NULL
    JOIN SERVICE.METER m
         ON m.PREMISE_ID = p.PREMISE_ID
        AND m.IS_ACTIVE  = TRUE
    WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
    QUALIFY ROW_NUMBER() OVER (ORDER BY COHORT_RANK) <= 932
);
-- EXPECTED: INTENDED_COHORT_SIZE = 932

-- Detailed intended cohort — top 20 rows (for operator review)
SELECT
    '2b_INTENDED_COHORT_SAMPLE'                               AS SECTION,
    ea.ENERGY_ACCOUNT_ID,
    MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SIM:' || $SIM_RUN_ID)), 9999991) AS COHORT_RANK
FROM CUSTOMER.ENERGY_ACCOUNT ea
JOIN SERVICE.PREMISE p
     ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
    AND p.END_DATE IS NULL
JOIN SERVICE.METER m
     ON m.PREMISE_ID = p.PREMISE_ID
    AND m.IS_ACTIVE  = TRUE
WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
QUALIFY ROW_NUMBER() OVER (ORDER BY COHORT_RANK) <= 20
ORDER BY COHORT_RANK;

-- =============================================================================
-- SECTION 3: ROWS INSERTED ON FIRST EXECUTION (intended cohort members)
-- These are the normal rows whose EA_ID is in the intended cohort.
-- They should be PRESERVED after repair.
-- =============================================================================
WITH intended_cohort AS (
    SELECT
        ea.ENERGY_ACCOUNT_ID,
        MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SIM:' || $SIM_RUN_ID)), 9999991) AS COHORT_RANK
    FROM CUSTOMER.ENERGY_ACCOUNT ea
    JOIN SERVICE.PREMISE p
         ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
        AND p.END_DATE IS NULL
    JOIN SERVICE.METER m
         ON m.PREMISE_ID = p.PREMISE_ID
        AND m.IS_ACTIVE  = TRUE
    WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
    QUALIFY ROW_NUMBER() OVER (ORDER BY COHORT_RANK) <= 932
)
SELECT
    '3_FIRST_RUN_ROWS'                                        AS SECTION,
    COUNT(*)                                                   AS ROWS_IN_INTENDED_COHORT,
    MIN(u.CREATED_AT)                                          AS EARLIEST_CREATED_AT,
    MAX(u.CREATED_AT)                                          AS LATEST_CREATED_AT
FROM BILLING.MONTHLY_USAGE u
JOIN intended_cohort ic ON ic.ENERGY_ACCOUNT_ID = u.ENERGY_ACCOUNT_ID
WHERE u.BILLING_MONTH = $BILLING_MONTH_TARGET
  AND u.USAGE_ID NOT LIKE 'USG-BZ-%'
  AND u.USAGE_ID NOT LIKE 'USG-INVK-%'
  AND u.USAGE_ID NOT LIKE 'USG-INVD-%';
-- EXPECTED: ROWS_IN_INTENDED_COHORT = 932

-- =============================================================================
-- SECTION 4: ROWS FROM ACCIDENTAL SECOND EXECUTION (outside intended cohort)
-- These are normal rows whose EA_ID was NOT in the intended cohort.
-- They should be DELETED after repair.
-- =============================================================================
WITH intended_cohort AS (
    SELECT
        ea.ENERGY_ACCOUNT_ID,
        MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SIM:' || $SIM_RUN_ID)), 9999991) AS COHORT_RANK
    FROM CUSTOMER.ENERGY_ACCOUNT ea
    JOIN SERVICE.PREMISE p
         ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
        AND p.END_DATE IS NULL
    JOIN SERVICE.METER m
         ON m.PREMISE_ID = p.PREMISE_ID
        AND m.IS_ACTIVE  = TRUE
    WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
    QUALIFY ROW_NUMBER() OVER (ORDER BY COHORT_RANK) <= 932
)
SELECT
    '4_ACCIDENTAL_SECOND_RUN_ROWS'                            AS SECTION,
    COUNT(*)                                                   AS ROWS_OUTSIDE_INTENDED_COHORT,
    MIN(u.CREATED_AT)                                          AS EARLIEST_CREATED_AT,
    MAX(u.CREATED_AT)                                          AS LATEST_CREATED_AT
FROM BILLING.MONTHLY_USAGE u
WHERE u.BILLING_MONTH = $BILLING_MONTH_TARGET
  AND u.USAGE_ID NOT LIKE 'USG-BZ-%'
  AND u.USAGE_ID NOT LIKE 'USG-INVK-%'
  AND u.USAGE_ID NOT LIKE 'USG-INVD-%'
  AND NOT EXISTS (
      SELECT 1 FROM intended_cohort ic
      WHERE ic.ENERGY_ACCOUNT_ID = u.ENERGY_ACCOUNT_ID
  );
-- EXPECTED: ROWS_OUTSIDE_INTENDED_COHORT = 932
-- These are the rows to be deleted.

-- =============================================================================
-- SECTION 5: CREATED_AT DISTRIBUTION — shows the two insertion timestamps
-- The two execution batches will have distinct CREATED_AT clusters.
-- This helps confirm which batch produced which rows.
-- =============================================================================
SELECT
    '5_CREATED_AT_DISTRIBUTION'                               AS SECTION,
    TO_CHAR(CREATED_AT, 'YYYY-MM-DD HH24:MI')                 AS CREATED_AT_MINUTE,
    COUNT(*)                                                   AS ROW_COUNT,
    COUNT(DISTINCT ENERGY_ACCOUNT_ID)                          AS DISTINCT_EA_IDS
FROM BILLING.MONTHLY_USAGE
WHERE BILLING_MONTH = $BILLING_MONTH_TARGET
  AND USAGE_ID NOT LIKE 'USG-BZ-%'
  AND USAGE_ID NOT LIKE 'USG-INVK-%'
  AND USAGE_ID NOT LIKE 'USG-INVD-%'
GROUP BY TO_CHAR(CREATED_AT, 'YYYY-MM-DD HH24:MI')
ORDER BY CREATED_AT_MINUTE;
-- EXPECTED: Two distinct time clusters, each with ~932 rows.
-- First cluster = first execution (intended cohort).
-- Second cluster = second execution (accidental cohort — to be removed).

-- =============================================================================
-- SECTION 6: BOUNDARY, INVALID AND CORRECTION ROWS TO PRESERVE
-- These rows must NOT be in the outside-cohort delete set.
-- =============================================================================
WITH intended_cohort AS (
    SELECT
        ea.ENERGY_ACCOUNT_ID,
        MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SIM:' || $SIM_RUN_ID)), 9999991) AS COHORT_RANK
    FROM CUSTOMER.ENERGY_ACCOUNT ea
    JOIN SERVICE.PREMISE p
         ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
        AND p.END_DATE IS NULL
    JOIN SERVICE.METER m
         ON m.PREMISE_ID = p.PREMISE_ID
        AND m.IS_ACTIVE  = TRUE
    WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
    QUALIFY ROW_NUMBER() OVER (ORDER BY COHORT_RANK) <= 932
),
special_rows AS (
    SELECT USAGE_ID, ENERGY_ACCOUNT_ID, BILLING_MONTH,
           CASE WHEN USAGE_ID LIKE 'USG-BZ-%'   THEN 'BOUNDARY'
                WHEN USAGE_ID LIKE 'USG-INVK-%' THEN 'INVALID_NEG_KWH'
                WHEN USAGE_ID LIKE 'USG-INVD-%' THEN 'INVALID_DATE_ORDER'
                WHEN IS_CORRECTION = TRUE        THEN 'CORRECTION'
                ELSE 'NORMAL'
           END AS ROW_TYPE
    FROM BILLING.MONTHLY_USAGE
    WHERE BILLING_MONTH = $BILLING_MONTH_TARGET
)
SELECT
    '6_SPECIAL_ROWS_PRESERVATION_CHECK'                       AS SECTION,
    sr.ROW_TYPE,
    sr.USAGE_ID,
    sr.ENERGY_ACCOUNT_ID,
    CASE WHEN ic.ENERGY_ACCOUNT_ID IS NOT NULL THEN 'IN_INTENDED_COHORT'
         ELSE 'NOT_IN_COHORT'
    END                                                        AS COHORT_MEMBERSHIP,
    'PRESERVE — do not delete'                                 AS DISPOSITION
FROM special_rows sr
LEFT JOIN intended_cohort ic ON ic.ENERGY_ACCOUNT_ID = sr.ENERGY_ACCOUNT_ID
WHERE sr.ROW_TYPE <> 'NORMAL'
ORDER BY sr.ROW_TYPE, sr.USAGE_ID;
-- EXPECTED: Boundary (1 row), INVALID_NEG_KWH (1 row), INVALID_DATE_ORDER (1 row)
-- may show COHORT_MEMBERSHIP = NOT_IN_COHORT — this is acceptable because
-- the special-row select logic uses USAGE_ID prefix, not cohort membership.
-- The DELETE in Section 9 explicitly preserves these rows via USAGE_ID prefix filters.

-- =============================================================================
-- SECTION 7: EXACT PROPOSED REMOVAL LIST (without executing DELETE)
-- Shows every USAGE_ID that would be deleted by the repair.
-- =============================================================================
WITH intended_cohort AS (
    SELECT
        ea.ENERGY_ACCOUNT_ID,
        MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SIM:' || $SIM_RUN_ID)), 9999991) AS COHORT_RANK
    FROM CUSTOMER.ENERGY_ACCOUNT ea
    JOIN SERVICE.PREMISE p
         ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
        AND p.END_DATE IS NULL
    JOIN SERVICE.METER m
         ON m.PREMISE_ID = p.PREMISE_ID
        AND m.IS_ACTIVE  = TRUE
    WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
    QUALIFY ROW_NUMBER() OVER (ORDER BY COHORT_RANK) <= 932
)
SELECT
    '7_PROPOSED_REMOVAL_LIST'                                 AS SECTION,
    u.USAGE_ID,
    u.ENERGY_ACCOUNT_ID,
    u.BILLING_MONTH,
    u.KWH_USAGE,
    u.TOTAL_BILLED,
    u.CREATED_AT,
    'PROPOSED_DELETE — outside named cohort'                   AS DISPOSITION
FROM BILLING.MONTHLY_USAGE u
WHERE u.BILLING_MONTH = $BILLING_MONTH_TARGET
  AND u.USAGE_ID NOT LIKE 'USG-BZ-%'
  AND u.USAGE_ID NOT LIKE 'USG-INVK-%'
  AND u.USAGE_ID NOT LIKE 'USG-INVD-%'
  AND NOT EXISTS (
      SELECT 1 FROM intended_cohort ic
      WHERE ic.ENERGY_ACCOUNT_ID = u.ENERGY_ACCOUNT_ID
  )
ORDER BY u.ENERGY_ACCOUNT_ID;
-- EXPECTED: 932 rows

-- =============================================================================
-- SECTION 7b: PROPOSED REMOVAL COUNT (summary for operator go/no-go decision)
-- =============================================================================
WITH intended_cohort AS (
    SELECT
        ea.ENERGY_ACCOUNT_ID,
        MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SIM:' || $SIM_RUN_ID)), 9999991) AS COHORT_RANK
    FROM CUSTOMER.ENERGY_ACCOUNT ea
    JOIN SERVICE.PREMISE p
         ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
        AND p.END_DATE IS NULL
    JOIN SERVICE.METER m
         ON m.PREMISE_ID = p.PREMISE_ID
        AND m.IS_ACTIVE  = TRUE
    WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
    QUALIFY ROW_NUMBER() OVER (ORDER BY COHORT_RANK) <= 932
)
SELECT
    '7b_PROPOSED_REMOVAL_SUMMARY'                             AS SECTION,
    COUNT(*)                                                   AS ROWS_TO_DELETE,
    ROUND(SUM(u.KWH_USAGE), 2)                                 AS KWH_TO_REMOVE,
    ROUND(SUM(u.TOTAL_BILLED), 2)                              AS BILLED_TO_REMOVE,
    'These rows are outside the named cohort SIM:' || $SIM_RUN_ID AS NOTE
FROM BILLING.MONTHLY_USAGE u
WHERE u.BILLING_MONTH = $BILLING_MONTH_TARGET
  AND u.USAGE_ID NOT LIKE 'USG-BZ-%'
  AND u.USAGE_ID NOT LIKE 'USG-INVK-%'
  AND u.USAGE_ID NOT LIKE 'USG-INVD-%'
  AND NOT EXISTS (
      SELECT 1 FROM intended_cohort ic
      WHERE ic.ENERGY_ACCOUNT_ID = u.ENERGY_ACCOUNT_ID
  );
-- EXPECTED: ROWS_TO_DELETE = 932

-- =============================================================================
-- SECTION 8: BUSINESS KEY CHECKS POST-CLEANUP (pre-flight for repair)
-- Verifies no remaining rows after the delete would violate the UNIQUE constraint.
-- =============================================================================
WITH intended_cohort AS (
    SELECT
        ea.ENERGY_ACCOUNT_ID,
        MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SIM:' || $SIM_RUN_ID)), 9999991) AS COHORT_RANK
    FROM CUSTOMER.ENERGY_ACCOUNT ea
    JOIN SERVICE.PREMISE p
         ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
        AND p.END_DATE IS NULL
    JOIN SERVICE.METER m
         ON m.PREMISE_ID = p.PREMISE_ID
        AND m.IS_ACTIVE  = TRUE
    WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
    QUALIFY ROW_NUMBER() OVER (ORDER BY COHORT_RANK) <= 932
),
rows_after_cleanup AS (
    SELECT ENERGY_ACCOUNT_ID, BILLING_MONTH
    FROM BILLING.MONTHLY_USAGE u
    WHERE u.BILLING_MONTH = $BILLING_MONTH_TARGET
      AND (
          -- Keep special rows always
          u.USAGE_ID LIKE 'USG-BZ-%'
          OR u.USAGE_ID LIKE 'USG-INVK-%'
          OR u.USAGE_ID LIKE 'USG-INVD-%'
          -- Keep normal rows that are in the intended cohort
          OR EXISTS (
              SELECT 1 FROM intended_cohort ic
              WHERE ic.ENERGY_ACCOUNT_ID = u.ENERGY_ACCOUNT_ID
          )
      )
)
SELECT
    '8_BUSINESS_KEY_CHECK_POST_CLEANUP'                        AS SECTION,
    COUNT(*)                                                    AS EXPECTED_ROW_COUNT_AFTER_CLEANUP,
    SUM(CASE WHEN dup_count > 1 THEN 1 ELSE 0 END)             AS BUSINESS_KEY_DUPLICATES,
    CASE WHEN SUM(CASE WHEN dup_count > 1 THEN 1 ELSE 0 END) = 0 THEN 'SAFE_TO_DELETE'
         ELSE 'WARNING_DUPLICATES_DETECTED'
    END                                                         AS REPAIR_SAFETY
FROM (
    SELECT ENERGY_ACCOUNT_ID, BILLING_MONTH, COUNT(*) AS dup_count
    FROM rows_after_cleanup
    GROUP BY ENERGY_ACCOUNT_ID, BILLING_MONTH
);
-- EXPECTED: BUSINESS_KEY_DUPLICATES = 0, REPAIR_SAFETY = SAFE_TO_DELETE
-- EXPECTED_ROW_COUNT_AFTER_CLEANUP = 935 (932 normal + 1 boundary + 2 invalid)

-- =============================================================================
-- SECTION 9: PROPOSED REPAIR DELETE (COMMENTED OUT — operator must review first)
--
-- PRE-CONDITIONS BEFORE UNCOMMENTING:
--   1. Section 2  INTENDED_COHORT_SIZE = 932
--   2. Section 4  ROWS_OUTSIDE_INTENDED_COHORT = 932
--   3. Section 7b ROWS_TO_DELETE = 932
--   4. Section 8  BUSINESS_KEY_DUPLICATES = 0  AND  REPAIR_SAFETY = SAFE_TO_DELETE
--   5. Section 6  boundary/invalid rows confirmed as PRESERVE
--
-- OPERATOR STEPS:
--   a. Confirm all pre-conditions above.
--   b. Remove the block-comment delimiters below.
--   c. Run the DELETE inside a transaction (BEGIN TRANSACTION … COMMIT / ROLLBACK).
--   d. After commit, rerun 10a-phase3-acceptance-summary.sql and confirm
--      MON-001 ACTUAL_COUNT = 932, OVERALL_STATUS = PASS.
-- =============================================================================

/*  <<<< OPERATOR: REMOVE THESE COMMENT DELIMITERS ONLY AFTER REVIEWING SECTIONS 1-8 >>>>

BEGIN TRANSACTION;

DELETE FROM BILLING.MONTHLY_USAGE
WHERE BILLING_MONTH = $BILLING_MONTH_TARGET
  AND USAGE_ID NOT LIKE 'USG-BZ-%'
  AND USAGE_ID NOT LIKE 'USG-INVK-%'
  AND USAGE_ID NOT LIKE 'USG-INVD-%'
  AND NOT EXISTS (
      SELECT 1
      FROM (
          SELECT
              ea.ENERGY_ACCOUNT_ID,
              MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'SIM:09-MONTHLY-SIM-001')), 9999991) AS COHORT_RANK
          FROM CUSTOMER.ENERGY_ACCOUNT ea
          JOIN SERVICE.PREMISE p
               ON p.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
              AND p.END_DATE IS NULL
          JOIN SERVICE.METER m
               ON m.PREMISE_ID = p.PREMISE_ID
              AND m.IS_ACTIVE  = TRUE
          WHERE ea.ACCOUNT_STATUS = 'ACTIVE'
          QUALIFY ROW_NUMBER() OVER (ORDER BY COHORT_RANK) <= 932
      ) ic
      WHERE ic.ENERGY_ACCOUNT_ID = BILLING.MONTHLY_USAGE.ENERGY_ACCOUNT_ID
  );

-- Verify result — should be 932 rows deleted
SELECT 'REPAIR_RESULT' AS LABEL, COUNT(*) AS ROWS_REMAINING_IN_TARGET_MONTH
FROM BILLING.MONTHLY_USAGE
WHERE BILLING_MONTH = $BILLING_MONTH_TARGET;
-- EXPECTED: 935 (932 normal + 1 boundary + 2 invalid)

-- COMMIT or ROLLBACK after reviewing the count above.
-- COMMIT;
-- ROLLBACK;

    <<<< END OPERATOR SECTION >>>> */

-- =============================================================================
-- SECTION 10: POST-CLEANUP EXPECTED RECONCILIATION (reference — not executed)
-- Shows what 10a-phase3-acceptance-summary.sql should report after cleanup.
-- =============================================================================
SELECT
    '10_EXPECTED_COUNTS_AFTER_REPAIR' AS SECTION,
    932 AS NORMAL_ROWS_EXPECTED,
    1   AS BOUNDARY_ROWS_EXPECTED,
    1   AS INVALID_NEG_KWH_EXPECTED,
    1   AS INVALID_DATE_ORDER_EXPECTED,
    935 AS TOTAL_ROWS_EXPECTED,
    'MON-001 will PASS when ACTUAL_COUNT = 932' AS MON_001_NOTE,
    'MON-004 / MON-005 / VIEW-014 remain EXPECTED_INVALID (correct)' AS INVALID_NOTE;
