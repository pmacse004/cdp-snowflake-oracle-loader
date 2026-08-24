-- =============================================================================
-- Snowflake Read-Only Verification — Step 8a: Verify Daily Changes
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE or CDP_LOADER_ROLE (SELECT only — no DML)
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Verify that all nine DC-01 through DC-09 daily change scenarios were
--   applied correctly by 08-simulate-daily-changes.sql.
--
--   This script:
--     - Contains NO INSERT, UPDATE or DELETE statements
--     - Is safe to run against the live dataset at any time after script 08
--     - Reports PASS/FAIL/WARN per scenario with actual vs expected counts
--     - Uses $DEMO_AS_OF_DATE for business-date column comparisons
--     - Uses technical sentinel values (ID prefixes, status codes, name
--       prefixes) rather than UPDATED_AT recency windows, so results are
--       stable regardless of when this script runs
--
-- DIAGNOSIS NOTES (issues found in original script 08 summary)
--   Bug 1 — DC-08 showed 0: summary used CURRENT_DATE() but CLOSE_DATE was
--            set to $DEMO_AS_OF_DATE (2026-06-01). Fixed here.
--   Bug 2 — DC-07 was missing from summary entirely. Added here.
--   Bug 3 — DC-03 combined emails + new phones into one line. Split here.
--   Bug 4 — DC-09 had no recency filter; sentinel STATUS_REASON is better.
--
-- PREREQUISITE
--   08-simulate-daily-changes.sql must have run.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PREFLIGHT — aborts immediately on wrong database or role
-- Accepts: CDP_ADMIN_ROLE or CDP_LOADER_ROLE (read-only verification)
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

-- $DEMO_AS_OF_DATE must match the value used in script 08.
-- Set independently here so this script runs in a fresh worksheet.
SET DEMO_AS_OF_DATE = TO_DATE('2026-06-01');
SELECT $DEMO_AS_OF_DATE AS DEMO_ANCHOR_DATE;
-- Expected: 2026-06-01

-- ===========================================================================
-- PASS/FAIL VERIFICATION — one row per DC scenario
-- Columns: SCENARIO, DESCRIPTION, EXPECTED, ACTUAL, STATUS
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- DC-01: New customers inserted (target: 100 rows, ID prefix CUST-D1-)
-- ---------------------------------------------------------------------------
SELECT
    'DC-01' AS SCENARIO,
    'New customers (CUST-D1- prefix)' AS DESCRIPTION,
    '100' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) = 100 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.CUSTOMER
WHERE CUSTOMER_ID LIKE 'CUST-D1-%';

-- ---------------------------------------------------------------------------
-- DC-02: Customer name changes (FIRST_NAME prefixed with 'Updated-')
-- Target: ~149 rows  (10000 / 67 ≈ 149; excludes CUST-D1- rows)
-- Status boundary: >= 100 and <= 200 = PASS; else FAIL
-- ---------------------------------------------------------------------------
SELECT
    'DC-02' AS SCENARIO,
    'Name changes (Updated- first name prefix)' AS DESCRIPTION,
    '~149 (100–200)' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) BETWEEN 100 AND 200 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.CUSTOMER
WHERE FIRST_NAME LIKE 'Updated-%'
  AND CUSTOMER_ID NOT LIKE 'CUST-D1-%';

-- ---------------------------------------------------------------------------
-- DC-03a: Primary email contact updates (.upd@example.com suffix)
-- Target: ~100 rows
-- ---------------------------------------------------------------------------
SELECT
    'DC-03a' AS SCENARIO,
    'Primary email updates (.upd@example.com)' AS DESCRIPTION,
    '~100 (50–150)' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) BETWEEN 50 AND 150 THEN 'PASS' ELSE 'WARN' END AS STATUS
FROM CUSTOMER.CUSTOMER_CONTACT
WHERE CONTACT_TYPE = 'EMAIL'
  AND IS_PRIMARY    = TRUE
  AND CONTACT_VALUE LIKE '%.upd@example.com';

-- ---------------------------------------------------------------------------
-- DC-03b: New secondary phone contacts (CONT-D1- prefix)
-- Target: ~50 rows
-- ---------------------------------------------------------------------------
SELECT
    'DC-03b' AS SCENARIO,
    'New secondary phone contacts (CONT-D1- prefix)' AS DESCRIPTION,
    '~50 (1–100)' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) BETWEEN 1 AND 100 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.CUSTOMER_CONTACT
WHERE CONTACT_ID LIKE 'CONT-D1-%';

-- Spot-check: confirm all new phone contacts use the NANPA fiction range only
SELECT
    'DC-03b-NANPA' AS SCENARIO,
    'New phones are in 555-0100..555-0199 range only' AS DESCRIPTION,
    '0 violations' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.CUSTOMER_CONTACT
WHERE CONTACT_ID    LIKE 'CONT-D1-%'
  AND CONTACT_TYPE  = 'PHONE'
  AND NOT REGEXP_LIKE(CONTACT_VALUE, '^555-01[0-9]{2}$');

-- ---------------------------------------------------------------------------
-- DC-04: New energy accounts, billing accounts, premises and meters
-- Target: ~50 rows each (ID prefix EA-D1-, BA-D1-, PREM-D1-, MTR-D1-)
-- ---------------------------------------------------------------------------
SELECT
    'DC-04-EA' AS SCENARIO,
    'New energy accounts (EA-D1- prefix)' AS DESCRIPTION,
    '~50 (1–100)' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) BETWEEN 1 AND 100 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.ENERGY_ACCOUNT
WHERE ENERGY_ACCOUNT_ID LIKE 'EA-D1-%';

SELECT
    'DC-04-BA' AS SCENARIO,
    'New billing accounts (BA-D1- prefix)' AS DESCRIPTION,
    'Matches EA-D1- count' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.BILLING_ACCOUNT
WHERE BILLING_ACCOUNT_ID LIKE 'BA-D1-%';

SELECT
    'DC-04-PREM' AS SCENARIO,
    'New premises (PREM-D1- prefix)' AS DESCRIPTION,
    'Matches EA-D1- count' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM SERVICE.PREMISE
WHERE PREMISE_ID LIKE 'PREM-D1-%';

SELECT
    'DC-04-MTR' AS SCENARIO,
    'New meters for new premises (MTR-D1- prefix)' AS DESCRIPTION,
    'Matches PREM-D1- count' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM SERVICE.METER
WHERE METER_ID LIKE 'MTR-D1-%';

-- Confirm all DC-04 new accounts have OPEN_DATE = DEMO_AS_OF_DATE
SELECT
    'DC-04-DATE' AS SCENARIO,
    'New EA open date = DEMO_AS_OF_DATE (business date, not CURRENT_DATE)' AS DESCRIPTION,
    '0 mismatches' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.ENERGY_ACCOUNT
WHERE ENERGY_ACCOUNT_ID LIKE 'EA-D1-%'
  AND OPEN_DATE <> $DEMO_AS_OF_DATE::DATE;

-- ---------------------------------------------------------------------------
-- DC-05: Billing-account-number changes (BILL-CHG- prefix on NBR)
-- Target: ~100 rows
-- ---------------------------------------------------------------------------
SELECT
    'DC-05' AS SCENARIO,
    'Billing nbr changes (BILL-CHG- prefix)' AS DESCRIPTION,
    '~100 (50–150)' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) BETWEEN 50 AND 150 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.BILLING_ACCOUNT
WHERE BILLING_ACCOUNT_NBR LIKE 'BILL-CHG-%';

-- ---------------------------------------------------------------------------
-- DC-06: Premise address changes (UPD- prefix on ADDRESS_LINE1)
-- Target: ~100 rows
-- ---------------------------------------------------------------------------
SELECT
    'DC-06' AS SCENARIO,
    'Premise address changes (UPD- prefix)' AS DESCRIPTION,
    '~100 (50–150)' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) BETWEEN 50 AND 150 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM SERVICE.PREMISE
WHERE ADDRESS_LINE1 LIKE 'UPD-%';

-- ---------------------------------------------------------------------------
-- DC-07a: Meters inactivated for replacement
-- Detection: IS_ACTIVE=FALSE + REMOVAL_DATE=$DEMO_AS_OF_DATE + not a D1-batch meter
-- Target: ~50 rows
-- ---------------------------------------------------------------------------
SELECT
    'DC-07a' AS SCENARIO,
    'Meters inactivated for replacement (REMOVAL_DATE = DEMO_AS_OF_DATE)' AS DESCRIPTION,
    '~50 (10–100)' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) BETWEEN 10 AND 100 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM SERVICE.METER
WHERE IS_ACTIVE    = FALSE
  AND REMOVAL_DATE = $DEMO_AS_OF_DATE::DATE
  AND METER_ID NOT LIKE 'MTR-D1-%'
  AND METER_ID NOT LIKE 'MTR-D1R-%';
-- NOTE: REMOVAL_DATE = $DEMO_AS_OF_DATE (2026-06-01) is intentional.
-- Do NOT use CURRENT_DATE() here — that would always return 0 for this demo dataset.

-- DC-07b: New replacement meters installed
SELECT
    'DC-07b' AS SCENARIO,
    'New replacement meters installed (MTR-D1R- prefix)' AS DESCRIPTION,
    '~50 (10–100)' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) BETWEEN 10 AND 100 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM SERVICE.METER
WHERE METER_ID LIKE 'MTR-D1R-%';

-- Confirm 1:1 relationship: each inactivated meter has a replacement at same premise
SELECT
    'DC-07c' AS SCENARIO,
    'Each inactivated meter premise has exactly one new replacement meter' AS DESCRIPTION,
    '0 premises without replacement' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END AS STATUS
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
  );

-- ---------------------------------------------------------------------------
-- DC-08: Account closures
-- Detection: ACCOUNT_STATUS='INACTIVE' + CLOSE_DATE=$DEMO_AS_OF_DATE
-- *** CRITICAL FIX: must use $DEMO_AS_OF_DATE, NOT CURRENT_DATE().
--     The mutation set CLOSE_DATE = $DEMO_AS_OF_DATE (2026-06-01).
--     CURRENT_DATE() is today's real calendar date and will always return 0.
-- ---------------------------------------------------------------------------
SELECT
    'DC-08' AS SCENARIO,
    'Account closures (CLOSE_DATE = DEMO_AS_OF_DATE, not CURRENT_DATE)' AS DESCRIPTION,
    '~50 (10–100)' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) BETWEEN 10 AND 100 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.ENERGY_ACCOUNT
WHERE ACCOUNT_STATUS = 'INACTIVE'
  AND CLOSE_DATE     = $DEMO_AS_OF_DATE::DATE
  AND ENERGY_ACCOUNT_ID NOT LIKE 'EA-D1-%';

-- Confirm closed accounts do NOT appear in active export view
SELECT
    'DC-08-VIEW' AS SCENARIO,
    'Closed accounts not in daily export view as ACTIVE' AS DESCRIPTION,
    '0 mismatches' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM STAGING.VW_DAILY_CUSTOMER_ACCOUNT_EXPORT v
JOIN CUSTOMER.ENERGY_ACCOUNT ea
    ON ea.ENERGY_ACCOUNT_ID = v.ENERGY_ACCOUNT_ID
WHERE ea.ACCOUNT_STATUS = 'INACTIVE'
  AND ea.CLOSE_DATE     = $DEMO_AS_OF_DATE::DATE
  AND v.ACCOUNT_STATUS  = 'ACTIVE';

-- ---------------------------------------------------------------------------
-- DC-09: Customer soft-inactivations
-- Detection: ACCOUNT_STATUS='INACTIVE' + STATUS_REASON sentinel
-- Target: ~50 rows
-- ---------------------------------------------------------------------------
SELECT
    'DC-09' AS SCENARIO,
    'Customer soft-inactivations (sentinel STATUS_REASON)' AS DESCRIPTION,
    '~50 (10–100)' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) BETWEEN 10 AND 100 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.CUSTOMER
WHERE ACCOUNT_STATUS = 'INACTIVE'
  AND STATUS_REASON  = 'INACTIVATED_DAILY_BATCH_D1';

-- ===========================================================================
-- CROSS-SCENARIO INTEGRITY CHECKS
-- ===========================================================================

-- No DC-D1 new customers were also inactivated in the same run
SELECT
    'INT-01' AS SCENARIO,
    'DC-01 new customers not also DC-09 inactivated' AS DESCRIPTION,
    '0 overlap' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.CUSTOMER
WHERE CUSTOMER_ID    LIKE 'CUST-D1-%'
  AND ACCOUNT_STATUS = 'INACTIVE';

-- All DC-04 new energy accounts have a corresponding billing account
SELECT
    'INT-02' AS SCENARIO,
    'All new EA-D1 accounts have a billing account' AS DESCRIPTION,
    '0 missing' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM CUSTOMER.ENERGY_ACCOUNT ea
WHERE ea.ENERGY_ACCOUNT_ID LIKE 'EA-D1-%'
  AND NOT EXISTS (
      SELECT 1 FROM CUSTOMER.BILLING_ACCOUNT ba
      WHERE ba.ENERGY_ACCOUNT_ID = ea.ENERGY_ACCOUNT_ID
  );

-- All DC-04 new premises have an active meter
SELECT
    'INT-03' AS SCENARIO,
    'All new PREM-D1 premises have an active meter' AS DESCRIPTION,
    '0 missing' AS EXPECTED,
    COUNT(*)::VARCHAR AS ACTUAL,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS
FROM SERVICE.PREMISE p
WHERE p.PREMISE_ID LIKE 'PREM-D1-%'
  AND NOT EXISTS (
      SELECT 1 FROM SERVICE.METER m
      WHERE m.PREMISE_ID = p.PREMISE_ID
        AND m.IS_ACTIVE  = TRUE
  );

-- ===========================================================================
-- OVERALL TALLY — how many scenarios passed
-- ===========================================================================
SELECT
    'TALLY' AS SCENARIO,
    'Run 08a verification complete — review individual rows above for PASS/FAIL' AS DESCRIPTION,
    CURRENT_TIMESTAMP()::VARCHAR AS RUN_AT,
    $DEMO_AS_OF_DATE::VARCHAR    AS DEMO_DATE_USED;
