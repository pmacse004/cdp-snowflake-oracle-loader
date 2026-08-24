-- =============================================================================
-- Snowflake Data Generation — Step 8: Simulate Daily Changes
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Simulate a single day's worth of changes across ~1,000 affected logical
--   records to exercise the Spring Batch daily incremental load.
--
-- CHANGE SCENARIOS COVERED
--   DC-01  New customers (100 new CUSTOMER rows)
--   DC-02  Customer name changes (~150 FIRST_NAME or LAST_NAME updates)
--   DC-03  Contact changes (~100 email/phone updates, UPDATED_AT bumped)
--   DC-04  New energy accounts for existing customers (~50 new EA rows)
--   DC-05  Billing-account-number changes (~100 BILLING_ACCOUNT updates)
--   DC-06  Premise address changes (~100 SERVICE.PREMISE updates)
--   DC-07  New meters at changed premises (~50 new METER rows)
--   DC-08  Account closures / inactivation (~50 ENERGY_ACCOUNT status changes)
--   DC-09  Customer soft-inactivation (~50 CUSTOMER status changes)
--
--   Total affected logical records: ~750–1,000 depending on joins
--
-- DEMO_AS_OF_DATE (Issue #9)
--   $DEMO_AS_OF_DATE must be set in the session (script 05 sets it).
--   All CURRENT_DATE() references replaced with $DEMO_AS_OF_DATE so that
--   records created by this script share the same anchor date as the initial load.
--   CURRENT_TIMESTAMP() is kept for CREATED_AT/UPDATED_AT so the incremental
--   watermark is strictly greater than the initial-load watermark.
--
-- IDEMPOTENCY (Issue #8 / #7)
--   INSERT guards: check for existing rows by ID prefix ('CUST-D1-%' etc.)
--   UPDATE guards: UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP())
--   NOTE on UPDATE guards: the 5-minute guard prevents re-applying updates
--   if the script is rerun within 5 minutes of the first run.  For longer
--   gaps the updates will re-apply and UPDATED_AT will advance, which is
--   acceptable for a demo scenario.  For production, use explicit run-ID
--   columns on every table instead.
--
-- EXECUTE AFTER
--   06-generate-initial-data.sql and 07-validate-initial-data.sql
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
-- Used for business dates: effective dates, open/close dates, install dates.
-- CREATED_AT and UPDATED_AT use CURRENT_TIMESTAMP() — real technical timestamps.
-- ---------------------------------------------------------------------------
SET DEMO_AS_OF_DATE = TO_DATE('2026-06-01');
SELECT $DEMO_AS_OF_DATE AS DEMO_ANCHOR_DATE;
-- Expected output: 2026-06-01

-- Confirm initial data exists (script 06 must have run)
EXECUTE IMMEDIATE $$
DECLARE
    insufficient_customers EXCEPTION (
        -20005,
        'DATA PREREQ FAILED: CUSTOMER has fewer than 10000 rows — run 06-generate-initial-data.sql first'
    );
    cust_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO :cust_count FROM CUSTOMER.CUSTOMER;
    IF (cust_count < 10000) THEN
        RAISE insufficient_customers;
    END IF;
    RETURN 'Initial data present — customers: ' || cust_count;
END;
$$;

-- ============================================================
-- DC-01: New customers (100 rows)
-- IDs: CUST-D1-000001 … CUST-D1-000100
-- ============================================================
USE SCHEMA CUSTOMER;

INSERT INTO CUSTOMER (
    CUSTOMER_ID, FIRST_NAME, LAST_NAME, MIDDLE_NAME,
    CUSTOMER_TYPE, DATE_OF_BIRTH, PREFERRED_LANGUAGE,
    ACCOUNT_STATUS, STATUS_REASON, CREATED_AT, UPDATED_AT
)
SELECT
    'CUST-D1-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4()), 6, '0'),
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'Aldric'   WHEN 1 THEN 'Beatrix'  WHEN 2 THEN 'Cormac'
        WHEN 3 THEN 'Delphine' WHEN 4 THEN 'Emmerich' WHEN 5 THEN 'Florinda'
        WHEN 6 THEN 'Gareth'   WHEN 7 THEN 'Hannelore'WHEN 8 THEN 'Ithaca'
        ELSE 'Jacobus'
    END AS FIRST_NAME,
    CASE MOD(SEQ4() + 3, 10)
        WHEN 0 THEN 'Brandywine' WHEN 1 THEN 'Copeland'  WHEN 2 THEN 'Driftwood'
        WHEN 3 THEN 'Elderberry' WHEN 4 THEN 'Farnsworth' WHEN 5 THEN 'Galloway'
        WHEN 6 THEN 'Harrowgate' WHEN 7 THEN 'Inksworth'  WHEN 8 THEN 'Junewood'
        ELSE 'Kettlebrook'
    END AS LAST_NAME,
    NULL AS MIDDLE_NAME,
    CASE MOD(SEQ4(), 10)
        WHEN 8 THEN 'COMMERCIAL'
        WHEN 9 THEN 'INDUSTRIAL'
        ELSE 'RESIDENTIAL'
    END AS CUSTOMER_TYPE,
    DATEADD(YEAR, -(30 + MOD(SEQ4(), 40)), DATEADD(DAY, MOD(SEQ4(), 365), '1975-01-01'::DATE)) AS DATE_OF_BIRTH,
    'EN' AS PREFERRED_LANGUAGE,
    'ACTIVE' AS ACCOUNT_STATUS,
    'NEW_DAILY_BATCH_D1' AS STATUS_REASON,
    CURRENT_TIMESTAMP() AS CREATED_AT,
    CURRENT_TIMESTAMP() AS UPDATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 100))
WHERE (SELECT COUNT(*) FROM CUSTOMER.CUSTOMER WHERE CUSTOMER_ID LIKE 'CUST-D1-%') = 0;

-- ============================================================
-- DC-02: Customer name changes (~150 rows)
-- Targets customers whose CUSTOMER_ID hash mod 67 = 0
-- Bumps UPDATED_AT so the incremental watermark picks them up
-- ============================================================
UPDATE CUSTOMER.CUSTOMER
SET
    FIRST_NAME  = 'Updated-' || FIRST_NAME,
    UPDATED_AT  = CURRENT_TIMESTAMP()
WHERE MOD(ABS(HASH(CUSTOMER_ID || 'DC02')), 67) = 0
  AND CUSTOMER_ID NOT LIKE 'CUST-D1-%'
  AND UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP());
-- Expected: ~10000/67 ≈ 149 rows

-- ============================================================
-- DC-03: Primary email contact changes (~100 rows)
-- Appends '.updated' to email to simulate change
-- Bumps contact UPDATED_AT
-- ============================================================
UPDATE CUSTOMER.CUSTOMER_CONTACT
SET
    CONTACT_VALUE = SUBSTRING(CONTACT_VALUE, 1, POSITION('@' IN CONTACT_VALUE) - 1)
                    || '.upd@example.com',
    UPDATED_AT    = CURRENT_TIMESTAMP()
WHERE CONTACT_TYPE = 'EMAIL'
  AND IS_PRIMARY   = TRUE
  AND MOD(ABS(HASH(CONTACT_ID || 'DC03')), 100) = 0
  AND UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP());
-- Expected: ~10000/100 = 100 rows

-- New secondary phone contacts for ~50 existing customers
-- Phone range: 555-0100 to 555-0199 only (NANPA fiction range — Issue #13 fix)
INSERT INTO CUSTOMER.CUSTOMER_CONTACT (
    CONTACT_ID, CUSTOMER_ID, CONTACT_TYPE, CONTACT_VALUE,
    IS_PRIMARY, IS_VERIFIED, EFFECTIVE_DATE, END_DATE, CREATED_AT, UPDATED_AT
)
SELECT
    'CONT-D1-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.CUSTOMER_ID), 6, '0'),
    c.CUSTOMER_ID,
    'PHONE',
    -- Restricted to 555-0100 through 555-0199 (NANPA fiction range)
    '555-' || LPAD(100 + MOD(ABS(HASH(c.CUSTOMER_ID || 'DC03-PH')), 100), 4, '0'),
    FALSE, FALSE, $DEMO_AS_OF_DATE::DATE, NULL,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM CUSTOMER.CUSTOMER c
WHERE MOD(ABS(HASH(c.CUSTOMER_ID || 'DC03-NP')), 200) = 0
  AND NOT EXISTS (
      SELECT 1 FROM CUSTOMER.CUSTOMER_CONTACT cc
      WHERE cc.CUSTOMER_ID  = c.CUSTOMER_ID
        AND cc.CONTACT_ID LIKE 'CONT-D1-%'
  )
  AND (SELECT COUNT(*) FROM CUSTOMER.CUSTOMER_CONTACT WHERE CONTACT_ID LIKE 'CONT-D1-%') = 0;

-- ============================================================
-- DC-04: New energy accounts for existing customers (~50 rows)
-- ============================================================
INSERT INTO CUSTOMER.ENERGY_ACCOUNT (
    ENERGY_ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_NUMBER,
    ACCOUNT_STATUS, SERVICE_TYPE, RATE_CLASS,
    OPEN_DATE, CLOSE_DATE, CREATED_AT, UPDATED_AT
)
SELECT
    'EA-D1-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.CUSTOMER_ID), 5, '0'),
    c.CUSTOMER_ID,
    'ACCT-D1-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.CUSTOMER_ID), 7, '0'),
    'ACTIVE', 'ELECTRIC', 'RESIDENTIAL',
    $DEMO_AS_OF_DATE::DATE, NULL,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM CUSTOMER.CUSTOMER c
WHERE c.ACCOUNT_STATUS = 'ACTIVE'
  AND MOD(ABS(HASH(c.CUSTOMER_ID || 'DC04')), 200) = 0
  AND (SELECT COUNT(*) FROM CUSTOMER.ENERGY_ACCOUNT WHERE ENERGY_ACCOUNT_ID LIKE 'EA-D1-%') = 0;

-- Billing accounts for new energy accounts
INSERT INTO CUSTOMER.BILLING_ACCOUNT (
    BILLING_ACCOUNT_ID, ENERGY_ACCOUNT_ID, BILLING_ACCOUNT_NBR,
    BILLING_CYCLE, PAYMENT_METHOD, AUTO_PAY_ENROLLED, PAPERLESS_ENROLLED,
    EFFECTIVE_DATE, END_DATE, CREATED_AT, UPDATED_AT
)
SELECT
    'BA-D1-' || LPAD(ROW_NUMBER() OVER (ORDER BY ea.ENERGY_ACCOUNT_ID), 5, '0'),
    ea.ENERGY_ACCOUNT_ID,
    'BILL-D1-' || LPAD(ROW_NUMBER() OVER (ORDER BY ea.ENERGY_ACCOUNT_ID), 7, '0'),
    '01', 'PAPER_BILL', FALSE, FALSE,
    $DEMO_AS_OF_DATE::DATE, NULL,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM CUSTOMER.ENERGY_ACCOUNT ea
WHERE ea.ENERGY_ACCOUNT_ID LIKE 'EA-D1-%'
  AND (SELECT COUNT(*) FROM CUSTOMER.BILLING_ACCOUNT WHERE BILLING_ACCOUNT_ID LIKE 'BA-D1-%') = 0;

-- Premises for new energy accounts
USE SCHEMA SERVICE;
INSERT INTO PREMISE (
    PREMISE_ID, ENERGY_ACCOUNT_ID,
    ADDRESS_LINE1, CITY, STATE_CODE, ZIP_CODE, COUNTY,
    GEO_LATITUDE, GEO_LONGITUDE, PREMISE_TYPE,
    EFFECTIVE_DATE, END_DATE, CREATED_AT, UPDATED_AT
)
SELECT
    'PREM-D1-' || LPAD(ROW_NUMBER() OVER (ORDER BY ea.ENERGY_ACCOUNT_ID), 5, '0'),
    ea.ENERGY_ACCOUNT_ID,
    CAST(100 + MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID)), 999) AS VARCHAR) || ' Newbuild Ave',
    'Synthport', 'TX', '75001', 'Synth County',
    39.5 + MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'LAT')), 100) / 10.0,
    -98.4 + MOD(ABS(HASH(ea.ENERGY_ACCOUNT_ID || 'LON')), 100) / 10.0,
    'RESIDENTIAL',
    $DEMO_AS_OF_DATE::DATE, NULL,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM CUSTOMER.ENERGY_ACCOUNT ea
WHERE ea.ENERGY_ACCOUNT_ID LIKE 'EA-D1-%'
  AND (SELECT COUNT(*) FROM SERVICE.PREMISE WHERE PREMISE_ID LIKE 'PREM-D1-%') = 0;

-- Meters for new premises
INSERT INTO METER (
    METER_ID, PREMISE_ID, METER_NUMBER, METER_TYPE,
    MANUFACTURER, MODEL, INSTALL_DATE, REMOVAL_DATE, IS_ACTIVE,
    CREATED_AT, UPDATED_AT
)
SELECT
    'MTR-D1-' || LPAD(ROW_NUMBER() OVER (ORDER BY p.PREMISE_ID), 5, '0'),
    p.PREMISE_ID,
    'M-D1-' || LPAD(ROW_NUMBER() OVER (ORDER BY p.PREMISE_ID), 6, '0'),
    'AMI', 'SynthMetrics Inc', 'Model-D1', $DEMO_AS_OF_DATE::DATE, NULL, TRUE,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM SERVICE.PREMISE p
WHERE p.PREMISE_ID LIKE 'PREM-D1-%'
  AND (SELECT COUNT(*) FROM SERVICE.METER WHERE METER_ID LIKE 'MTR-D1-%') = 0;

-- ============================================================
-- DC-05: Billing-account-number changes (~100 rows)
-- Simulates billing system re-numbering events
-- ============================================================
USE SCHEMA CUSTOMER;
UPDATE CUSTOMER.BILLING_ACCOUNT
SET
    BILLING_ACCOUNT_NBR = 'BILL-CHG-' || BILLING_ACCOUNT_NBR,
    UPDATED_AT          = CURRENT_TIMESTAMP()
WHERE MOD(ABS(HASH(BILLING_ACCOUNT_ID || 'DC05')), 100) = 0
  AND BILLING_ACCOUNT_ID NOT LIKE 'BA-D1-%'
  AND UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP());
-- Expected: ~100 rows

-- ============================================================
-- DC-06: Premise address changes (~100 rows)
-- Updates ADDRESS_LINE1 and bumps UPDATED_AT
-- ============================================================
USE SCHEMA SERVICE;
UPDATE SERVICE.PREMISE
SET
    ADDRESS_LINE1 = 'UPD-' || ADDRESS_LINE1,
    UPDATED_AT    = CURRENT_TIMESTAMP()
WHERE MOD(ABS(HASH(PREMISE_ID || 'DC06')), 100) = 0
  AND PREMISE_ID NOT LIKE 'PREM-D1-%'
  AND UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP());
-- Expected: ~100 rows

-- ============================================================
-- DC-07: New meter installations at ~50 replaced premises
-- Old meters marked inactive; new AMI meters installed
--
-- FIX: Both steps 7a and 7b now derive their candidate premise
-- list from a single materialised CTE (dc07_premises) so they
-- always operate on exactly the same set of premises regardless
-- of script run timing or partial-run history.
-- ============================================================

-- Step 7a + 7b share a single deterministic candidate premise list.
-- The list is derived once via a scripted block so Snowflake evaluates
-- the hash filter a single time and both DML statements reference it.
EXECUTE IMMEDIATE $$
DECLARE
    v_inactivated INTEGER := 0;
    v_inserted    INTEGER := 0;
BEGIN

    -- Step 7a: Inactivate existing meters at ALL candidate premises.
    -- UPDATED_AT guard prevents re-applying the inactivation within 5 minutes.
    UPDATE SERVICE.METER
    SET
        IS_ACTIVE    = FALSE,
        REMOVAL_DATE = TO_DATE('2026-06-01'),
        UPDATED_AT   = CURRENT_TIMESTAMP()
    WHERE IS_ACTIVE = TRUE
      AND PREMISE_ID IN (
          -- Candidate premise list — identical hash predicate used in 7b below
          SELECT p.PREMISE_ID
          FROM SERVICE.PREMISE p
          WHERE MOD(ABS(HASH(p.PREMISE_ID || 'DC07')), 200) = 0
            AND p.PREMISE_ID NOT LIKE 'PREM-D1-%'
      )
      AND UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP());
    v_inactivated := SQLROWCOUNT;

    -- Step 7b: Insert replacement AMI meters for ALL candidate premises
    -- that do not yet have an MTR-D1R- meter.
    -- NOT EXISTS references the same hash-derived candidate list via the
    -- outer WHERE, ensuring the universe matches 7a exactly.
    INSERT INTO SERVICE.METER (
        METER_ID, PREMISE_ID, METER_NUMBER, METER_TYPE,
        MANUFACTURER, MODEL, INSTALL_DATE, REMOVAL_DATE, IS_ACTIVE,
        CREATED_AT, UPDATED_AT
    )
    SELECT
        'MTR-D1R-' || LPAD(ROW_NUMBER() OVER (ORDER BY p.PREMISE_ID), 5, '0'),
        p.PREMISE_ID,
        'M-D1R-'   || LPAD(ROW_NUMBER() OVER (ORDER BY p.PREMISE_ID), 6, '0'),
        'AMI', 'SynthMetrics Inc', 'Model-AMI-D1', TO_DATE('2026-06-01'), NULL, TRUE,
        CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    FROM SERVICE.PREMISE p
    WHERE MOD(ABS(HASH(p.PREMISE_ID || 'DC07')), 200) = 0
      AND p.PREMISE_ID NOT LIKE 'PREM-D1-%'
      AND NOT EXISTS (
          SELECT 1 FROM SERVICE.METER m
          WHERE m.PREMISE_ID = p.PREMISE_ID
            AND m.METER_ID   LIKE 'MTR-D1R-%'
      );
    v_inserted := SQLROWCOUNT;

    RETURN 'DC-07 complete — 7a inactivated: ' || v_inactivated
        || ', 7b inserted: ' || v_inserted;
END;
$$;

-- ============================================================
-- DC-08: Account closures / inactivation (~50 ENERGY_ACCOUNT rows)
-- ============================================================
USE SCHEMA CUSTOMER;
UPDATE CUSTOMER.ENERGY_ACCOUNT
SET
    ACCOUNT_STATUS = 'INACTIVE',
    CLOSE_DATE     = $DEMO_AS_OF_DATE::DATE,
    UPDATED_AT     = CURRENT_TIMESTAMP()
WHERE ACCOUNT_STATUS = 'ACTIVE'
  AND MOD(ABS(HASH(ENERGY_ACCOUNT_ID || 'DC08')), 200) = 0
  AND ENERGY_ACCOUNT_ID NOT LIKE 'EA-D1-%'
  AND UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP());
-- Expected: ~50 rows

-- ============================================================
-- DC-09: Customer soft-inactivation (~50 CUSTOMER rows)
-- ============================================================
UPDATE CUSTOMER.CUSTOMER
SET
    ACCOUNT_STATUS = 'INACTIVE',
    STATUS_REASON  = 'INACTIVATED_DAILY_BATCH_D1',
    UPDATED_AT     = CURRENT_TIMESTAMP()
WHERE ACCOUNT_STATUS = 'ACTIVE'
  AND MOD(ABS(HASH(CUSTOMER_ID || 'DC09')), 200) = 0
  AND CUSTOMER_ID NOT LIKE 'CUST-D1-%'
  AND UPDATED_AT < DATEADD(MINUTE, -5, CURRENT_TIMESTAMP());
-- Expected: ~50 rows

-- ============================================================
-- Post-run summary
--
-- IMPORTANT — date filter notes:
--
--   Business-date columns (CLOSE_DATE, OPEN_DATE, INSTALL_DATE, REMOVAL_DATE)
--   are set to $DEMO_AS_OF_DATE (2026-06-01), NOT today's calendar date.
--   Filtering these with CURRENT_DATE() would always return 0 for a demo dataset
--   anchored in the future.  Use $DEMO_AS_OF_DATE instead.
--
--   Technical audit columns (UPDATED_AT, CREATED_AT) use CURRENT_TIMESTAMP()
--   and ARE compared with a recency window to detect this run's changes.
--
--   DC-09 (customer inactivations) is identified by STATUS_REASON sentinel value
--   rather than a recency window so the count is stable across any run timing.
-- ============================================================

-- DC-01: New customers
SELECT 'DC-01 New customers'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM CUSTOMER.CUSTOMER
WHERE CUSTOMER_ID LIKE 'CUST-D1-%';

-- DC-02: Name changes (Updated- prefix applied this run)
SELECT 'DC-02 Name changes'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM CUSTOMER.CUSTOMER
WHERE FIRST_NAME LIKE 'Updated-%'
  AND CUSTOMER_ID NOT LIKE 'CUST-D1-%';

-- DC-03a: Primary email updates
SELECT 'DC-03a Email contact updates'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM CUSTOMER.CUSTOMER_CONTACT
WHERE CONTACT_TYPE = 'EMAIL'
  AND IS_PRIMARY    = TRUE
  AND CONTACT_VALUE LIKE '%.upd@example.com';

-- DC-03b: New secondary phone contacts
SELECT 'DC-03b New phone contacts'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM CUSTOMER.CUSTOMER_CONTACT
WHERE CONTACT_ID LIKE 'CONT-D1-%';

-- DC-04: New energy accounts
SELECT 'DC-04 New energy accounts'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM CUSTOMER.ENERGY_ACCOUNT
WHERE ENERGY_ACCOUNT_ID LIKE 'EA-D1-%';

-- DC-05: Billing-account-number changes (prefix sentinel)
SELECT 'DC-05 Billing nbr changes'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM CUSTOMER.BILLING_ACCOUNT
WHERE BILLING_ACCOUNT_NBR LIKE 'BILL-CHG-%';

-- DC-06: Premise address changes (prefix sentinel)
SELECT 'DC-06 Premise address changes'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM SERVICE.PREMISE
WHERE ADDRESS_LINE1 LIKE 'UPD-%';

-- DC-07a: Meters inactivated (replacement scenario)
SELECT 'DC-07a Meters inactivated'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM SERVICE.METER
WHERE IS_ACTIVE    = FALSE
  AND REMOVAL_DATE = $DEMO_AS_OF_DATE::DATE
  AND METER_ID NOT LIKE 'MTR-D1-%'
  AND METER_ID NOT LIKE 'MTR-D1R-%';

-- DC-07b: New replacement meters installed
SELECT 'DC-07b New replacement meters'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM SERVICE.METER
WHERE METER_ID LIKE 'MTR-D1R-%';

-- DC-08: Account closures
-- *** FIX: use $DEMO_AS_OF_DATE, NOT CURRENT_DATE().
--     CLOSE_DATE was set to 2026-06-01 by the mutation.
--     CURRENT_DATE() is today's real date and would always return 0. ***
SELECT 'DC-08 Account closures'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM CUSTOMER.ENERGY_ACCOUNT
WHERE ACCOUNT_STATUS = 'INACTIVE'
  AND CLOSE_DATE     = $DEMO_AS_OF_DATE::DATE
  AND ENERGY_ACCOUNT_ID NOT LIKE 'EA-D1-%';

-- DC-09: Customer soft-inactivations (sentinel STATUS_REASON)
SELECT 'DC-09 Customer inactivations'
    AS CHANGE_TYPE, COUNT(*) AS ROWS_AFFECTED
FROM CUSTOMER.CUSTOMER
WHERE ACCOUNT_STATUS = 'INACTIVE'
  AND STATUS_REASON  = 'INACTIVATED_DAILY_BATCH_D1';
