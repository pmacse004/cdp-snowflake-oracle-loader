-- =============================================================================
-- CDP Snowflake to Oracle Data Loader
-- Audit and Repair: Meter Pairing Defect (DC-07)
-- Step 08b — READ-ONLY dry-run (no INSERT executed without operator action)
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Diagnose 4 premises where DC-07 inactivated the original meter but
--   did not insert an MTR-D1R- replacement meter.
--
-- ROOT CAUSE
--   Script 08 DC-07 used two independent sub-queries to derive the candidate
--   premise list for steps 7a (inactivate) and 7b (insert replacement):
--
--     Step 7a (UPDATE):
--       WHERE PREMISE_ID IN (
--           SELECT PREMISE_ID FROM SERVICE.PREMISE
--           WHERE MOD(ABS(HASH(PREMISE_ID || 'DC07')), 200) = 0
--             AND PREMISE_ID NOT LIKE 'PREM-D1-%'
--       )
--       AND UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP())   ← idempotency guard
--
--     Step 7b (INSERT):
--       WHERE MOD(ABS(HASH(p.PREMISE_ID || 'DC07')), 200) = 0
--         AND p.PREMISE_ID NOT LIKE 'PREM-D1-%'
--         AND NOT EXISTS (MTR-D1R- already at this premise)
--
--   The 5-minute UPDATED_AT guard on 7a means: on a second partial run, meters
--   updated less than 5 minutes ago are skipped by 7a, while 7b's NOT EXISTS
--   guard sees a prior incomplete MTR-D1R insert attempt and also skips those
--   premises.  On yet another partial run at a different timing window,
--   7a may re-inactivate but 7b's NOT EXISTS catches a previously-inserted
--   MTR-D1R and skips -- leaving some premises with no active meter.
--
--   The hash formula is identical in both steps so they SHOULD select the same
--   set.  The gap arises purely from the 7a UPDATED_AT guard firing at a
--   different point relative to 7b's NOT EXISTS guard across multiple partial runs.
--
-- CORRECT ALGORITHM (now implemented in 08-simulate-daily-changes.sql)
--   A single CTE materializes the candidate premise list once.
--   Both 7a and 7b reference that same CTE, ensuring they always operate on
--   exactly the same set of premises.
--
-- CLEANUP APPROACH
--   For each of the 4 missing premises:
--     - The original meter has already been inactivated (IS_ACTIVE = FALSE,
--       REMOVAL_DATE = DEMO_AS_OF_DATE).
--     - An MTR-D1R- replacement must be inserted.
--   The repair INSERT block below is commented out; operator must review and
--   uncomment only after confirming the dry-run output in Sections 1-5.
--
-- SAFE TO RERUN WITHOUT MODIFICATION — THIS SCRIPT CONTAINS NO ACTIVE DML.
--   All INSERT statements are commented out.
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

SET DEMO_AS_OF_DATE = TO_DATE('2026-06-01');

SELECT $DEMO_AS_OF_DATE AS DEMO_ANCHOR_DATE;

-- =============================================================================
-- SECTION 1: CANDIDATE PREMISE SET (deterministic from hash)
-- Both 7a and 7b should operate on exactly this set.
-- =============================================================================
SELECT
    '1_CANDIDATE_PREMISES'                                    AS SECTION,
    COUNT(*)                                                   AS TOTAL_CANDIDATE_PREMISES
FROM SERVICE.PREMISE
WHERE MOD(ABS(HASH(PREMISE_ID || 'DC07')), 200) = 0
  AND PREMISE_ID NOT LIKE 'PREM-D1-%';
-- EXPECTED: ~50 premises (10000/200 = 50)

-- Detailed list — 20 row sample
SELECT
    '1b_CANDIDATE_SAMPLE'                                     AS SECTION,
    PREMISE_ID,
    MOD(ABS(HASH(PREMISE_ID || 'DC07')), 200)                  AS HASH_MOD
FROM SERVICE.PREMISE
WHERE MOD(ABS(HASH(PREMISE_ID || 'DC07')), 200) = 0
  AND PREMISE_ID NOT LIKE 'PREM-D1-%'
ORDER BY PREMISE_ID
LIMIT 20;

-- =============================================================================
-- SECTION 2: INACTIVATED METERS (old meters marked IS_ACTIVE = FALSE by 7a)
-- =============================================================================
SELECT
    '2_INACTIVATED_METERS'                                    AS SECTION,
    COUNT(*)                                                   AS INACTIVATED_METER_COUNT
FROM SERVICE.METER
WHERE IS_ACTIVE     = FALSE
  AND REMOVAL_DATE  = $DEMO_AS_OF_DATE::DATE
  AND METER_ID NOT LIKE 'MTR-D1-%'
  AND METER_ID NOT LIKE 'MTR-D1R-%';
-- EXPECTED: ~50 (one per candidate premise)

-- =============================================================================
-- SECTION 3: NEW MTR-D1R REPLACEMENT METERS (inserted by 7b)
-- =============================================================================
SELECT
    '3_REPLACEMENT_METERS'                                    AS SECTION,
    COUNT(*)                                                   AS REPLACEMENT_METER_COUNT
FROM SERVICE.METER
WHERE METER_ID LIKE 'MTR-D1R-%';
-- EXPECTED: ~46 (50 minus the 4 that were missed)

-- =============================================================================
-- SECTION 4: MISSING REPLACEMENTS — premises with inactivated meter but no MTR-D1R
-- These are the 4 premises that require a repair INSERT.
-- =============================================================================
SELECT
    '4_MISSING_REPLACEMENTS'                                  AS SECTION,
    old_m.PREMISE_ID,
    old_m.METER_ID                                             AS INACTIVATED_METER_ID,
    old_m.REMOVAL_DATE,
    old_m.UPDATED_AT                                           AS INACTIVATED_AT,
    'MTR-D1R-REPAIR-' || LPAD(ROW_NUMBER() OVER (ORDER BY old_m.PREMISE_ID), 4, '0')
                                                               AS PROPOSED_NEW_METER_ID,
    'M-D1R-REPAIR-' || LPAD(ROW_NUMBER() OVER (ORDER BY old_m.PREMISE_ID), 5, '0')
                                                               AS PROPOSED_NEW_METER_NBR
FROM SERVICE.METER old_m
WHERE old_m.IS_ACTIVE    = FALSE
  AND old_m.REMOVAL_DATE = $DEMO_AS_OF_DATE::DATE
  AND old_m.METER_ID NOT LIKE 'MTR-D1-%'
  AND old_m.METER_ID NOT LIKE 'MTR-D1R-%'
  AND NOT EXISTS (
      SELECT 1 FROM SERVICE.METER new_m
      WHERE new_m.PREMISE_ID = old_m.PREMISE_ID
        AND new_m.METER_ID   LIKE 'MTR-D1R-%'
        AND new_m.IS_ACTIVE  = TRUE
  )
ORDER BY old_m.PREMISE_ID;
-- EXPECTED: 4 rows (the unpaired premises)

-- =============================================================================
-- SECTION 5: REPLACEMENTS WITHOUT A MATCHING OLD METER
-- (should be 0 — sanity check for the inverse condition)
-- =============================================================================
SELECT
    '5_REPLACEMENTS_WITHOUT_OLD_METER'                        AS SECTION,
    COUNT(*)                                                   AS COUNT_WITHOUT_OLD_METER
FROM SERVICE.METER new_m
WHERE new_m.METER_ID LIKE 'MTR-D1R-%'
  AND NOT EXISTS (
      SELECT 1 FROM SERVICE.METER old_m
      WHERE old_m.PREMISE_ID   = new_m.PREMISE_ID
        AND old_m.IS_ACTIVE    = FALSE
        AND old_m.REMOVAL_DATE = $DEMO_AS_OF_DATE::DATE
  );
-- EXPECTED: 0

-- =============================================================================
-- SECTION 6: PREMISES WITH ZERO ACTIVE METERS (includes the 4 broken premises)
-- =============================================================================
SELECT
    '6_PREMISES_WITH_ZERO_ACTIVE_METERS'                      AS SECTION,
    p.PREMISE_ID,
    p.ENERGY_ACCOUNT_ID,
    (SELECT COUNT(*) FROM SERVICE.METER m
     WHERE m.PREMISE_ID = p.PREMISE_ID AND m.IS_ACTIVE = TRUE) AS ACTIVE_METER_COUNT
FROM SERVICE.PREMISE p
WHERE p.END_DATE IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM SERVICE.METER m
      WHERE m.PREMISE_ID = p.PREMISE_ID AND m.IS_ACTIVE = TRUE
  )
ORDER BY p.PREMISE_ID;
-- EXPECTED: 4 rows (the unpaired premises)

-- =============================================================================
-- SECTION 7: PREMISES WITH MORE THAN ONE ACTIVE METER
-- (should be 0 — sanity check)
-- =============================================================================
SELECT
    '7_PREMISES_WITH_MULTIPLE_ACTIVE_METERS'                  AS SECTION,
    PREMISE_ID,
    COUNT(*) AS ACTIVE_METER_COUNT
FROM SERVICE.METER
WHERE IS_ACTIVE = TRUE
GROUP BY PREMISE_ID
HAVING COUNT(*) > 1;
-- EXPECTED: 0 rows

-- =============================================================================
-- SECTION 8: PROPOSED INSERT REPAIR ROWS (dry-run output for operator review)
-- These are the exact values that would be inserted by the repair block below.
-- Review this output carefully before uncommenting the INSERT.
-- =============================================================================
SELECT
    '8_PROPOSED_REPAIR_INSERTS'                               AS SECTION,
    'MTR-D1R-REPAIR-' || LPAD(repair_seq.SEQ, 4, '0')         AS METER_ID,
    old_m.PREMISE_ID,
    'M-D1R-REPAIR-' || LPAD(repair_seq.SEQ, 5, '0')           AS METER_NUMBER,
    'AMI'                                                      AS METER_TYPE,
    'SynthMetrics Inc'                                         AS MANUFACTURER,
    'Model-AMI-D1-REPAIR'                                      AS MODEL,
    $DEMO_AS_OF_DATE::DATE                                     AS INSTALL_DATE,
    NULL                                                       AS REMOVAL_DATE,
    TRUE                                                       AS IS_ACTIVE
FROM SERVICE.METER old_m
JOIN (
    SELECT
        PREMISE_ID,
        ROW_NUMBER() OVER (ORDER BY PREMISE_ID) AS SEQ
    FROM SERVICE.METER
    WHERE IS_ACTIVE    = FALSE
      AND REMOVAL_DATE = $DEMO_AS_OF_DATE::DATE
      AND METER_ID NOT LIKE 'MTR-D1-%'
      AND METER_ID NOT LIKE 'MTR-D1R-%'
      AND NOT EXISTS (
          SELECT 1 FROM SERVICE.METER new_m
          WHERE new_m.PREMISE_ID = SERVICE.METER.PREMISE_ID
            AND new_m.METER_ID   LIKE 'MTR-D1R-%'
            AND new_m.IS_ACTIVE  = TRUE
      )
) repair_seq ON repair_seq.PREMISE_ID = old_m.PREMISE_ID
WHERE old_m.IS_ACTIVE    = FALSE
  AND old_m.REMOVAL_DATE = $DEMO_AS_OF_DATE::DATE
  AND old_m.METER_ID NOT LIKE 'MTR-D1-%'
  AND old_m.METER_ID NOT LIKE 'MTR-D1R-%'
  AND NOT EXISTS (
      SELECT 1 FROM SERVICE.METER new_m
      WHERE new_m.PREMISE_ID = old_m.PREMISE_ID
        AND new_m.METER_ID   LIKE 'MTR-D1R-%'
        AND new_m.IS_ACTIVE  = TRUE
  )
ORDER BY old_m.PREMISE_ID;
-- EXPECTED: 4 rows showing the proposed repair meter IDs and premises

-- =============================================================================
-- SECTION 9: REPAIR INSERT (COMMENTED OUT — operator must review Sections 1-8 first)
--
-- PRE-CONDITIONS BEFORE UNCOMMENTING:
--   1. Section 4 returns exactly 4 rows (missing replacements)
--   2. Section 5 returns 0 rows (no orphaned replacements)
--   3. Section 6 returns exactly 4 rows (premises with 0 active meters)
--   4. Section 7 returns 0 rows (no premises with >1 active meter)
--   5. Section 8 shows exactly 4 proposed inserts with PREMISE_ID matching Section 4
--
-- OPERATOR STEPS:
--   a. Confirm all pre-conditions above.
--   b. Remove the block-comment delimiters below.
--   c. Run the INSERT.
--   d. Rerun 10a-phase3-acceptance-summary.sql and confirm DC-07c STATUS = PASS.
-- =============================================================================

/*  <<<< OPERATOR: REMOVE THESE COMMENT DELIMITERS ONLY AFTER REVIEWING SECTIONS 1-8 >>>>

INSERT INTO SERVICE.METER (
    METER_ID, PREMISE_ID, METER_NUMBER, METER_TYPE,
    MANUFACTURER, MODEL, INSTALL_DATE, REMOVAL_DATE, IS_ACTIVE,
    CREATED_AT, UPDATED_AT
)
SELECT
    'MTR-D1R-REPAIR-' || LPAD(ROW_NUMBER() OVER (ORDER BY old_m.PREMISE_ID), 4, '0'),
    old_m.PREMISE_ID,
    'M-D1R-REPAIR-'   || LPAD(ROW_NUMBER() OVER (ORDER BY old_m.PREMISE_ID), 5, '0'),
    'AMI', 'SynthMetrics Inc', 'Model-AMI-D1-REPAIR',
    $DEMO_AS_OF_DATE::DATE, NULL, TRUE,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM SERVICE.METER old_m
WHERE old_m.IS_ACTIVE    = FALSE
  AND old_m.REMOVAL_DATE = $DEMO_AS_OF_DATE::DATE
  AND old_m.METER_ID NOT LIKE 'MTR-D1-%'
  AND old_m.METER_ID NOT LIKE 'MTR-D1R-%'
  AND NOT EXISTS (
      SELECT 1 FROM SERVICE.METER new_m
      WHERE new_m.PREMISE_ID = old_m.PREMISE_ID
        AND new_m.METER_ID   LIKE 'MTR-D1R-%'
        AND new_m.IS_ACTIVE  = TRUE
  )
  -- Guard: only operate on verified missing-replacement premises (Section 4)
  AND MOD(ABS(HASH(old_m.PREMISE_ID || 'DC07')), 200) = 0
ORDER BY old_m.PREMISE_ID;

-- Verify result
SELECT COUNT(*) AS REPAIRED_PREMISES_NOW_WITH_ACTIVE_METER
FROM SERVICE.METER
WHERE METER_ID LIKE 'MTR-D1R-REPAIR-%' AND IS_ACTIVE = TRUE;
-- EXPECTED: 4

    <<<< END OPERATOR SECTION >>>> */
