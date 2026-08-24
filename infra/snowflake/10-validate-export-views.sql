-- =============================================================================
-- Snowflake Data Validation — Step 10: Validate Export Views
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE or CDP_LOADER_ROLE (SELECT only)
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Validate that both export views produce correct, complete and
--   reconcilable output against the source tables.
--
-- INVALID RECORDS
--   Script 09 intentionally inserts controlled invalid records with
--   compact USAGE_ID prefixes USG-INVK-% (negative KWH) and USG-INVD-%
--   (inverted date order).  These are EXPECTED_INVALID records — they are
--   present in BILLING.MONTHLY_USAGE (and therefore in the view) but must be
--   REJECTED by Spring Batch, not loaded to Oracle.
--   Check V-IR-001 verifies these records ARE present (needed for the demo).
--   Check V-IR-002 documents their expected status explicitly.
--   Check V-IR-003 verifies the boundary USG-BZ-% record is present (valid, should load).
--   Do NOT claim V-IR-001 as a business-rule PASS — it is a test-setup check.
--
-- REPORT FORMAT
--   Every check returns: CHECK_ID, DESCRIPTION, STATUS, OFFENDING_ROWS, DETAIL
--
-- PREREQUISITE
--   Scripts 05 through 09 must have run.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PREFLIGHT CHECK — aborts immediately on wrong database or wrong role
-- Accepts: CDP_ADMIN_ROLE or CDP_LOADER_ROLE (read-only validation script)
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

-- ===========================================================================
-- Section 1: VW_DAILY_CUSTOMER_ACCOUNT_EXPORT — Row Count and Coverage
-- ===========================================================================

SELECT 'V-DV-001' AS CHECK_ID,
    'Daily view: row count > 0' AS DESCRIPTION,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS,
    CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS OFFENDING_ROWS,
    COUNT(*) || ' rows in VW_DAILY_CUSTOMER_ACCOUNT_EXPORT' AS DETAIL
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT;

SELECT 'V-DV-002',
    'Daily view: ENERGY_ACCOUNT_ID is never null',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows with NULL ENERGY_ACCOUNT_ID'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE ENERGY_ACCOUNT_ID IS NULL;

SELECT 'V-DV-003',
    'Daily view: CUSTOMER_ID is never null',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows with NULL CUSTOMER_ID'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE CUSTOMER_ID IS NULL;

SELECT 'V-DV-004',
    'Daily view: FULL_NAME_NORMALIZED is populated',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows with NULL or empty FULL_NAME_NORMALIZED'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE FULL_NAME_NORMALIZED IS NULL OR TRIM(FULL_NAME_NORMALIZED) = '';

SELECT 'V-DV-005',
    'Daily view: RECORD_EFFECTIVE_TS is populated for all rows',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows with NULL RECORD_EFFECTIVE_TS'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE RECORD_EFFECTIVE_TS IS NULL;

SELECT 'V-DV-006',
    'Daily view: EMAIL_ADDRESS is populated for all rows (every customer has primary email)',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END,
    COUNT(*),
    COUNT(*) || ' rows with NULL EMAIL_ADDRESS'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE EMAIL_ADDRESS IS NULL;

SELECT 'V-DV-007',
    'Daily view: PREMISE_ID populated for all active accounts',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' active energy account rows without PREMISE_ID'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE ACCOUNT_STATUS = 'ACTIVE' AND PREMISE_ID IS NULL;

SELECT 'V-DV-008',
    'Daily view: METER_ID populated where PREMISE_ID exists',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END,
    COUNT(*),
    COUNT(*) || ' rows with PREMISE_ID but no METER_ID'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE PREMISE_ID IS NOT NULL AND METER_ID IS NULL;

SELECT 'V-DV-009',
    'Daily view: BILLING_ACCOUNT_NBR populated for all active accounts',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' active accounts without billing account number'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE ACCOUNT_STATUS = 'ACTIVE' AND BILLING_ACCOUNT_NBR IS NULL;

SELECT 'V-DV-010',
    'Daily view: FULL_ADDRESS is populated where ADDRESS_LINE1 exists',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows with ADDRESS_LINE1 but null FULL_ADDRESS'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE ADDRESS_LINE1 IS NOT NULL AND (FULL_ADDRESS IS NULL OR TRIM(FULL_ADDRESS) = '');

-- ===========================================================================
-- Section 2: Daily view — Composite Watermark Coverage
-- ===========================================================================

SELECT 'V-DV-011',
    'Daily view: RECORD_EFFECTIVE_TS = MAX of all contributing UPDATED_AT columns',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows where RECORD_EFFECTIVE_TS is not the maximum UPDATED_AT'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT v
JOIN CUSTOMER.ENERGY_ACCOUNT ea ON ea.ENERGY_ACCOUNT_ID = v.ENERGY_ACCOUNT_ID
JOIN CUSTOMER.CUSTOMER        c  ON c.CUSTOMER_ID        = v.CUSTOMER_ID
WHERE v.RECORD_EFFECTIVE_TS < GREATEST(
    COALESCE(c.UPDATED_AT,  '1970-01-01'::TIMESTAMP_TZ),
    COALESCE(ea.UPDATED_AT, '1970-01-01'::TIMESTAMP_TZ)
);

SELECT 'V-DV-012',
    'Daily view: distinct ENERGY_ACCOUNT_ID = ENERGY_ACCOUNT row count (one row per account)',
    CASE WHEN a.CNT = b.CNT THEN 'PASS' ELSE 'FAIL' END,
    ABS(a.CNT - b.CNT),
    a.CNT || ' view rows vs ' || b.CNT || ' energy account rows'
FROM (SELECT COUNT(DISTINCT ENERGY_ACCOUNT_ID) AS CNT FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT) a,
     (SELECT COUNT(*) AS CNT FROM CUSTOMER.ENERGY_ACCOUNT) b;

-- ===========================================================================
-- Section 3: VW_MONTHLY_USAGE_BILLING_EXPORT — Row Count and Fields
-- ===========================================================================

SELECT 'V-MV-001',
    'Monthly view: row count > 0',
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END,
    COUNT(*) || ' rows in VW_MONTHLY_USAGE_BILLING_EXPORT'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT;

SELECT 'V-MV-002',
    'Monthly view: USAGE_ID is never null',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows with NULL USAGE_ID'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT WHERE USAGE_ID IS NULL;

SELECT 'V-MV-003',
    'Monthly view: BILLING_MONTH matches YYYY-MM format',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows with invalid BILLING_MONTH format'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT
WHERE NOT REGEXP_LIKE(BILLING_MONTH, '^[0-9]{4}-[0-9]{2}$');

SELECT 'V-MV-004',
    'Monthly view: RATE_PLAN is not null (join to REF succeeded or rate plan present)',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows with NULL RATE_PLAN'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT WHERE RATE_PLAN IS NULL;

SELECT 'V-MV-005',
    'Monthly view: FIXED_RATE is not null (rate plan JSON parsed correctly)',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END,
    COUNT(*),
    COUNT(*) || ' rows where FIXED_RATE is NULL (rate plan not found or invalid JSON)'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT WHERE FIXED_RATE IS NULL;

SELECT 'V-MV-006',
    'Monthly view: ENERGY_RATE_PER_KWH is not null',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END,
    COUNT(*),
    COUNT(*) || ' rows where ENERGY_RATE_PER_KWH is NULL'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT WHERE ENERGY_RATE_PER_KWH IS NULL;

SELECT 'V-MV-007',
    'Monthly view: TAX_RATE is not null',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END,
    COUNT(*),
    COUNT(*) || ' rows where TAX_RATE is NULL'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT WHERE TAX_RATE IS NULL;

SELECT 'V-MV-008',
    'Monthly view: no negative rates (would indicate data error)',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows with a negative rate component'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT
WHERE (FIXED_RATE         IS NOT NULL AND FIXED_RATE         < 0)
   OR (ENERGY_RATE_PER_KWH IS NOT NULL AND ENERGY_RATE_PER_KWH < 0)
   OR (DEMAND_RATE_PER_KW  IS NOT NULL AND DEMAND_RATE_PER_KW  < 0)
   OR (TAX_RATE            IS NOT NULL AND TAX_RATE            < 0);

-- ===========================================================================
-- Section 4: Charge Calculation Reconciliation
-- ===========================================================================

SELECT 'V-CR-001',
    'Monthly view: CALC_TOTAL_BILLED = CALC_SUBTOTAL + CALC_TAX_AMOUNT (within 0.01)',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows where total != subtotal + tax (tolerance 0.01)'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT
WHERE CALC_TOTAL_BILLED  IS NOT NULL
  AND CALC_SUBTOTAL      IS NOT NULL
  AND CALC_TAX_AMOUNT    IS NOT NULL
  AND ABS(CALC_TOTAL_BILLED - (CALC_SUBTOTAL + CALC_TAX_AMOUNT)) > 0.01;

SELECT 'V-CR-002',
    'Monthly view: CALC_SUBTOTAL = CALC_FIXED + CALC_ENERGY + CALC_DEMAND (within 0.01)',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows where subtotal component sum mismatches'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT
WHERE CALC_SUBTOTAL      IS NOT NULL
  AND CALC_FIXED_CHARGE  IS NOT NULL
  AND CALC_ENERGY_CHARGE IS NOT NULL
  AND CALC_DEMAND_CHARGE IS NOT NULL
  AND ABS(CALC_SUBTOTAL - (CALC_FIXED_CHARGE + CALC_ENERGY_CHARGE + CALC_DEMAND_CHARGE)) > 0.01;

SELECT 'V-CR-003',
    'Monthly view: no negative CALC charges',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows with a negative calculated charge'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT
WHERE (CALC_FIXED_CHARGE  IS NOT NULL AND CALC_FIXED_CHARGE  < 0)
   OR (CALC_ENERGY_CHARGE IS NOT NULL AND CALC_ENERGY_CHARGE < 0)
   OR (CALC_DEMAND_CHARGE IS NOT NULL AND CALC_DEMAND_CHARGE < 0)
   OR (CALC_TAX_AMOUNT    IS NOT NULL AND CALC_TAX_AMOUNT    < 0)
   OR (CALC_TOTAL_BILLED  IS NOT NULL AND CALC_TOTAL_BILLED  < 0);

SELECT 'V-CR-004',
    'Monthly view: CALC_DEMAND_CHARGE = 0 when DEMAND_RATE_PER_KW is NULL (ICA MU-AC-09)',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    COUNT(*) || ' rows where null demand rate produced non-zero demand charge'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT
WHERE DEMAND_RATE_PER_KW IS NULL
  AND CALC_DEMAND_CHARGE != 0;

SELECT 'V-CR-005',
    'Monthly view: source TOTAL_BILLED vs CALC_TOTAL_BILLED within tolerance (0.05)',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END,
    COUNT(*),
    COUNT(*) || ' rows where source and calculated totals differ by > 0.05'
FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT v
JOIN BILLING.MONTHLY_USAGE u ON u.USAGE_ID = v.USAGE_ID
WHERE v.CALC_TOTAL_BILLED IS NOT NULL
  AND u.TOTAL_BILLED       IS NOT NULL
  AND ABS(u.TOTAL_BILLED - v.CALC_TOTAL_BILLED) > 0.05;

-- ===========================================================================
-- Section 5: Aggregate reconciliation
-- ===========================================================================

SELECT 'V-AR-001',
    'Monthly view: total KWH agrees with source table (within 1 KWH)',
    CASE WHEN ABS(v.TOTAL_KWH - s.TOTAL_KWH) <= 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN ABS(v.TOTAL_KWH - s.TOTAL_KWH) <= 1 THEN 0 ELSE 1 END,
    'View KWH=' || v.TOTAL_KWH || ' Source KWH=' || s.TOTAL_KWH
FROM (SELECT ROUND(SUM(KWH_USAGE), 2) AS TOTAL_KWH FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT) v,
     (SELECT ROUND(SUM(KWH_USAGE), 2) AS TOTAL_KWH FROM BILLING.MONTHLY_USAGE) s;

SELECT 'V-AR-002',
    'Monthly view row count = source MONTHLY_USAGE row count',
    CASE WHEN v.CNT = s.CNT THEN 'PASS' ELSE 'FAIL' END,
    ABS(v.CNT - s.CNT),
    'View rows=' || v.CNT || ' Source rows=' || s.CNT
FROM (SELECT COUNT(*) AS CNT FROM STAGING.VW_MONTHLY_USAGE_BILLING_EXPORT) v,
     (SELECT COUNT(*) AS CNT FROM BILLING.MONTHLY_USAGE) s;

-- ===========================================================================
-- Section 6: VARIANT NULL handling validation
-- ===========================================================================

-- V-VN-001 through V-VN-005: VARIANT bracket-notation syntax tests
-- Use PARSE_JSON(literal)['key'] — the correct bracket notation.
SELECT 'V-VN-001',
    'TRY_TO_DECIMAL on valid JSON number returns non-null',
    CASE WHEN TRY_TO_DECIMAL(PARSE_JSON('{"fixed":8.50}')['fixed']::STRING, 10, 2) IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
    0,
    'Expected 8.50, got: ' || COALESCE(TRY_TO_DECIMAL(PARSE_JSON('{"fixed":8.50}')['fixed']::STRING,10,2)::VARCHAR, 'NULL');

SELECT 'V-VN-002',
    'TRY_TO_DECIMAL on missing key returns NULL',
    CASE WHEN TRY_TO_DECIMAL(PARSE_JSON('{}')['fixed']::STRING, 10, 2) IS NULL THEN 'PASS' ELSE 'FAIL' END,
    0,
    'Expected NULL, got: ' || COALESCE(TRY_TO_DECIMAL(PARSE_JSON('{}')['fixed']::STRING,10,2)::VARCHAR, 'NULL as expected');

SELECT 'V-VN-003',
    'TRY_TO_DECIMAL on JSON null returns NULL',
    CASE WHEN TRY_TO_DECIMAL(PARSE_JSON('{"demand":null}')['demand']::STRING, 10, 6) IS NULL THEN 'PASS' ELSE 'FAIL' END,
    0,
    'Expected NULL (json null demand), got: ' || COALESCE(TRY_TO_DECIMAL(PARSE_JSON('{"demand":null}')['demand']::STRING,10,6)::VARCHAR, 'NULL as expected');

SELECT 'V-VN-004',
    'TRY_TO_DECIMAL on invalid text returns NULL (no exception)',
    CASE WHEN TRY_TO_DECIMAL(PARSE_JSON('{"fixed":"N/A"}')['fixed']::STRING, 10, 2) IS NULL THEN 'PASS' ELSE 'FAIL' END,
    0,
    'Expected NULL for "N/A", got: ' || COALESCE(TRY_TO_DECIMAL(PARSE_JSON('{"fixed":"N/A"}')['fixed']::STRING,10,2)::VARCHAR, 'NULL as expected');

SELECT 'V-VN-005',
    'TRY_TO_DECIMAL on negative rate returns negative number (not zeroed)',
    CASE WHEN TRY_TO_DECIMAL(PARSE_JSON('{"energy":-0.05}')['energy']::STRING, 10, 6) = -0.050000 THEN 'PASS' ELSE 'FAIL' END,
    0,
    'Expected -0.050000, got: ' || COALESCE(TRY_TO_DECIMAL(PARSE_JSON('{"energy":-0.05}')['energy']::STRING,10,6)::VARCHAR, 'NULL');

-- ===========================================================================
-- Section 7: Expected-invalid record checks
-- USAGE_ID prefix legend for invalid/boundary records (compact codes from script 09):
--   USG-BZ-NNNNNN-YYYYMM   Boundary zero-KWH
--   USG-INVK-NNNNNN-YYYYMM Invalid negative-KWH  (VR-USAGE-005)
--   USG-INVD-NNNNNN-YYYYMM Invalid inverted-date  (VR-USAGE-003)
-- These checks verify demo test data is in place — they are NOT business-rule
-- validations.  "PASS" here means the test setup is correct, not that the
-- data is valid.  These records must be REJECTED by Spring Batch.
-- ===========================================================================

-- V-IR-001: Confirm EXPECTED_INVALID records are present (test-setup check)
SELECT 'V-IR-001' AS CHECK_ID,
    'EXPECTED_INVALID records present for Spring Batch rejection test (test-setup check only)' AS DESCRIPTION,
    CASE WHEN COUNT(*) >= 2 THEN 'SETUP_OK' ELSE 'SETUP_WARN' END AS STATUS,
    GREATEST(0, 2 - COUNT(*)) AS OFFENDING_ROWS,
    COUNT(*) || ' rows with USG-INVK-% or USG-INVD-% prefix — these are EXPECTED_INVALID' AS DETAIL
FROM BILLING.MONTHLY_USAGE
WHERE USAGE_ID LIKE 'USG-INVK-%'
   OR USAGE_ID LIKE 'USG-INVD-%';
-- Expected: SETUP_OK (2 rows — one INVK, one INVD).
-- These records must NOT be loaded to Oracle.

-- V-IR-002: Show EXPECTED_INVALID record details for documentation
SELECT 'V-IR-002' AS CHECK_ID,
    'EXPECTED_INVALID record inventory' AS DESCRIPTION,
    'EXPECTED_INVALID' AS STATUS,
    0 AS OFFENDING_ROWS,
    USAGE_ID || ' | ' || BILLING_MONTH || ' | KWH=' || KWH_USAGE::VARCHAR
        || ' | DAYS=' || BILLING_DAYS::VARCHAR
        || ' | REASON=' || COALESCE(CORRECTION_REASON, 'MISSING') AS DETAIL
FROM BILLING.MONTHLY_USAGE
WHERE USAGE_ID LIKE 'USG-INVK-%'
   OR USAGE_ID LIKE 'USG-INVD-%'
ORDER BY USAGE_ID;
-- Each row should show SIM_RUN_ID and scenario code in the REASON column.
-- Spring Batch must reject all rows returned here into ETL_RECORD_ERROR.

-- V-IR-003: Confirm boundary zero-KWH record is present (test-setup check)
SELECT 'V-IR-003' AS CHECK_ID,
    'BOUNDARY zero-KWH record present (test-setup check only)' AS DESCRIPTION,
    CASE WHEN COUNT(*) >= 1 THEN 'SETUP_OK' ELSE 'SETUP_WARN' END AS STATUS,
    GREATEST(0, 1 - COUNT(*)) AS OFFENDING_ROWS,
    COUNT(*) || ' rows with USG-BZ-% prefix' AS DETAIL
FROM BILLING.MONTHLY_USAGE
WHERE USAGE_ID LIKE 'USG-BZ-%';
-- Expected: SETUP_OK (1 row). This is a VALID record that Spring Batch should LOAD.

-- ===========================================================================
-- Section 8: Daily view incremental change coverage
-- ===========================================================================

SELECT 'V-IC-001',
    'Daily view includes recently updated customers from DC-02 name changes',
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'WARN' END,
    0,
    COUNT(*) || ' rows with FIRST_NAME starting with Updated-'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE FIRST_NAME LIKE 'Updated-%';

SELECT 'V-IC-002',
    'Daily view includes new CUST-D1 customers from DC-01',
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'WARN' END,
    0,
    COUNT(*) || ' new D1 customer rows in daily view'
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT
WHERE CUSTOMER_ID LIKE 'CUST-D1-%';
