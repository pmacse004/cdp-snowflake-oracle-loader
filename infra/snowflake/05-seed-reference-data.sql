-- =============================================================================
-- Snowflake Data Generation — Step 5: Seed Reference Data
-- =============================================================================
-- Run as: CDP_ADMIN_ROLE
-- Database: CDP_UTIL_DB
-- Warehouse: CDP_LOADER_WH
--
-- PURPOSE
--   Populate REF.CODE_VALUE with all synthetic reference codes required by:
--     - Export view label lookups  (ACCT_STATUS, CUST_TYPE)
--     - Charge calculations        (RATE_PLAN — rates in ATTRIBUTES VARIANT)
--     - Validation rules           (METER_TYPE, READ_TYPE, CONTACT_TYPE, etc.)
--
-- COLUMN DESIGN (Issue #1 fix — ATTRIBUTES/CODE_LABEL separation)
--   CODE_LABEL  VARCHAR(500) — human-readable text label ONLY.
--                              Example: 'Residential Standard'
--   ATTRIBUTES  VARIANT      — machine-readable structured parameters.
--                              Non-null only for RATE_PLAN rows.
--                              Built with OBJECT_CONSTRUCT(…) — native VARIANT.
--                              Accessed via: rp.ATTRIBUTES['fixed']::STRING
--                              Includes "synthetic":true flag on all rate rows.
--
--   IMPORTANT: Never store JSON strings in CODE_LABEL.  Script 04 reads
--   rate parameters from ATTRIBUTES, not from CODE_LABEL.
--
-- SYNTHETIC DATA NOTICE
--   All codes, labels, rates and values are entirely synthetic demonstration
--   data.  No real utility tariffs, customer categories or regulatory codes
--   are represented.  Rate values are fictional.
--
-- IDEMPOTENCY
--   Uses INSERT … SELECT WHERE NOT EXISTS on (DOMAIN, CODE).
--   Safe to rerun — will not duplicate existing rows.
--   RATE_PLAN rows also UPDATE ATTRIBUTES if the column is NULL (handles
--   the case where 03a was run after 05 on a partial environment).
--
-- DEMO_AS_OF_DATE
--   SET here and made available for downstream scripts via Snowflake session
--   variable.  All date arithmetic in subsequent scripts should reference
--   $DEMO_AS_OF_DATE rather than CURRENT_DATE() so a complete demo run
--   is anchored to one fixed date regardless of when the script executes.
--   Default: the 1st of the current month so billing-month calculations
--   produce clean YYYY-MM boundaries.
--
-- EXECUTION ORDER
--   Must run AFTER 03a-add-reference-attributes.sql (or fresh 03).
--   Must run BEFORE 06-generate-initial-data.sql.
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
USE SCHEMA REF;
USE WAREHOUSE CDP_LOADER_WH;

-- Confirm ATTRIBUTES column exists (must have been added by 03a or updated 03)
EXECUTE IMMEDIATE $$
DECLARE
    missing_attributes_column EXCEPTION (
        -20003,
        'PREFLIGHT FAILED: REF.CODE_VALUE.ATTRIBUTES column not found — run 03a-add-reference-attributes.sql first'
    );
    col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO :col_count
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'REF'
      AND TABLE_NAME   = 'CODE_VALUE'
      AND COLUMN_NAME  = 'ATTRIBUTES';
    IF (col_count = 0) THEN
        RAISE missing_attributes_column;
    END IF;
    RETURN 'ATTRIBUTES column present — OK';
END;
$$;

-- ---------------------------------------------------------------------------
-- DEMO_AS_OF_DATE — fixed demo anchor date
-- ---------------------------------------------------------------------------
-- *** OPERATOR PARAMETER — change this value to re-anchor the entire dataset ***
-- Must be the FIRST day of a month (YYYY-MM-01) so that billing-month
-- calculations produce clean YYYY-MM boundaries.
-- Every script 05-10 sets the same literal independently so each script is
-- runnable in a fresh worksheet without relying on a prior session variable.
-- ---------------------------------------------------------------------------
SET DEMO_AS_OF_DATE = TO_DATE('2026-06-01');
SELECT $DEMO_AS_OF_DATE AS DEMO_ANCHOR_DATE;
-- Expected output: 2026-06-01

-- ===========================================================================
-- 1. ACCT_STATUS — Account / Customer lifecycle status
-- ===========================================================================
INSERT INTO CODE_VALUE (DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
SELECT v.* FROM (
    SELECT 'ACCT_STATUS', 'ACTIVE',    'Active',     NULL, 'Account is active and in good standing', 10, TRUE
    UNION ALL SELECT 'ACCT_STATUS', 'INACTIVE',  'Inactive',   NULL, 'Account is inactive; no service',       20, TRUE
    UNION ALL SELECT 'ACCT_STATUS', 'PENDING',   'Pending',    NULL, 'Account pending activation',            30, TRUE
    UNION ALL SELECT 'ACCT_STATUS', 'CLOSED',    'Closed',     NULL, 'Account permanently closed',            40, TRUE
    UNION ALL SELECT 'ACCT_STATUS', 'SUSPENDED', 'Suspended',  NULL, 'Account suspended; temporary',          50, TRUE
) v(DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
WHERE NOT EXISTS (
    SELECT 1 FROM CODE_VALUE x WHERE x.DOMAIN = v.DOMAIN AND x.CODE = v.CODE
);

-- ===========================================================================
-- 2. CUST_TYPE — Customer classification
-- ===========================================================================
INSERT INTO CODE_VALUE (DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
SELECT v.* FROM (
    SELECT 'CUST_TYPE', 'RESIDENTIAL', 'Residential', NULL, 'Residential household customer', 10, TRUE
    UNION ALL SELECT 'CUST_TYPE', 'COMMERCIAL',  'Commercial',  NULL, 'Commercial business customer',   20, TRUE
    UNION ALL SELECT 'CUST_TYPE', 'INDUSTRIAL',  'Industrial',  NULL, 'Industrial high-consumption',    30, TRUE
) v(DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
WHERE NOT EXISTS (
    SELECT 1 FROM CODE_VALUE x WHERE x.DOMAIN = v.DOMAIN AND x.CODE = v.CODE
);

-- ===========================================================================
-- 3. CONTACT_TYPE — Contact record type
-- ===========================================================================
INSERT INTO CODE_VALUE (DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
SELECT v.* FROM (
    SELECT 'CONTACT_TYPE', 'EMAIL',   'Email Address',   NULL, 'Electronic mail contact',       10, TRUE
    UNION ALL SELECT 'CONTACT_TYPE', 'PHONE',   'Phone Number',    NULL, 'Voice telephone contact',       20, TRUE
    UNION ALL SELECT 'CONTACT_TYPE', 'MAILING', 'Mailing Address', NULL, 'Postal mail address',           30, TRUE
    UNION ALL SELECT 'CONTACT_TYPE', 'BILLING', 'Billing Address', NULL, 'Billing correspondence address',40, TRUE
    UNION ALL SELECT 'CONTACT_TYPE', 'SERVICE', 'Service Address', NULL, 'Service delivery address',      50, TRUE
) v(DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
WHERE NOT EXISTS (
    SELECT 1 FROM CODE_VALUE x WHERE x.DOMAIN = v.DOMAIN AND x.CODE = v.CODE
);

-- ===========================================================================
-- 4. METER_TYPE — Physical meter classification
-- ===========================================================================
INSERT INTO CODE_VALUE (DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
SELECT v.* FROM (
    SELECT 'METER_TYPE', 'ANALOG',  'Analog Meter',     NULL, 'Electromechanical dial meter',         10, TRUE
    UNION ALL SELECT 'METER_TYPE', 'DIGITAL', 'Digital Meter',    NULL, 'Electronic digital display meter',      20, TRUE
    UNION ALL SELECT 'METER_TYPE', 'AMI',     'Smart Meter (AMI)',NULL, 'Advanced Metering Infrastructure',      30, TRUE
) v(DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
WHERE NOT EXISTS (
    SELECT 1 FROM CODE_VALUE x WHERE x.DOMAIN = v.DOMAIN AND x.CODE = v.CODE
);

-- ===========================================================================
-- 5. READ_TYPE — Meter read method
-- ===========================================================================
INSERT INTO CODE_VALUE (DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
SELECT v.* FROM (
    SELECT 'READ_TYPE', 'ACTUAL',    'Actual Read',    NULL, 'Reading taken directly from meter',    10, TRUE
    UNION ALL SELECT 'READ_TYPE', 'ESTIMATED', 'Estimated Read', NULL, 'Estimated from historical usage',      20, TRUE
) v(DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
WHERE NOT EXISTS (
    SELECT 1 FROM CODE_VALUE x WHERE x.DOMAIN = v.DOMAIN AND x.CODE = v.CODE
);

-- ===========================================================================
-- 6. SERVICE_TYPE — Utility service type
-- ===========================================================================
INSERT INTO CODE_VALUE (DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
SELECT v.* FROM (
    SELECT 'SERVICE_TYPE', 'ELECTRIC', 'Electric Service',   NULL, 'Standard electricity delivery service', 10, TRUE
    UNION ALL SELECT 'SERVICE_TYPE', 'GAS',     'Gas Service',       NULL, 'Natural gas delivery service',          20, TRUE
    UNION ALL SELECT 'SERVICE_TYPE', 'SOLAR',   'Solar Net Meter',   NULL, 'Solar net-metering service',            30, TRUE
) v(DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
WHERE NOT EXISTS (
    SELECT 1 FROM CODE_VALUE x WHERE x.DOMAIN = v.DOMAIN AND x.CODE = v.CODE
);

-- ===========================================================================
-- 7. PAYMENT_METHOD — Billing payment method
-- ===========================================================================
INSERT INTO CODE_VALUE (DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
SELECT v.* FROM (
    SELECT 'PAYMENT_METHOD', 'PAPER_BILL', 'Paper Bill',     NULL, 'Monthly paper invoice by mail',     10, TRUE
    UNION ALL SELECT 'PAYMENT_METHOD', 'AUTO_PAY',   'Auto Pay',       NULL, 'Automatic bank or card debit',      20, TRUE
    UNION ALL SELECT 'PAYMENT_METHOD', 'ONLINE',     'Online Payment', NULL, 'Customer pays via web portal',      30, TRUE
) v(DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
WHERE NOT EXISTS (
    SELECT 1 FROM CODE_VALUE x WHERE x.DOMAIN = v.DOMAIN AND x.CODE = v.CODE
);

-- ===========================================================================
-- 8. RATE_PLAN — Pricing tariff codes
--
-- CODE_LABEL  = human-readable description (plain text — NO JSON)
-- ATTRIBUTES  = OBJECT_CONSTRUCT(…) VARIANT with rate parameters:
--     "fixed"     NUMBER  — fixed monthly charge in USD
--     "energy"    NUMBER  — energy rate in USD/kWh (6 decimal precision)
--     "demand"    NUMBER  — demand rate in USD/kW (null if plan has no demand)
--     "tax"       NUMBER  — tax rate as a decimal fraction (0.080 = 8%)
--     "synthetic" BOOLEAN — always true; marks this as demo data
--
-- Accessed in export view via:
--     rp.ATTRIBUTES['fixed']::STRING      (then TRY_TO_DECIMAL for type safety)
--     rp.ATTRIBUTES['energy']::STRING     etc.
--
-- *** SYNTHETIC DEMONSTRATION VALUES — NOT REAL UTILITY TARIFFS ***
-- ===========================================================================
INSERT INTO CODE_VALUE (DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
SELECT v.DOMAIN, v.CODE, v.CODE_LABEL,
       OBJECT_CONSTRUCT(
           'fixed',     v.FIXED_RATE,
           'energy',    v.ENERGY_RATE,
           'demand',    v.DEMAND_RATE,
           'tax',       v.TAX_RATE,
           'synthetic', TRUE
       ) AS ATTRIBUTES,
       v.DESCRIPTION, v.DISPLAY_ORDER, v.IS_ACTIVE
FROM (
    -- col order: DOMAIN, CODE, CODE_LABEL, FIXED_RATE, ENERGY_RATE, DEMAND_RATE, TAX_RATE, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE
    -- Residential plans (no demand charge — demand stored as JSON null)
    SELECT 'RATE_PLAN', 'RES-1', 'Residential Standard',        8.50, 0.115000, NULL,      0.080000, '[SYNTHETIC] fixed $8.50/mo, $0.1150/kWh, 8% tax',           10, TRUE
    UNION ALL SELECT 'RATE_PLAN', 'RES-2', 'Residential Time-of-Use',     8.50, 0.090000, NULL,      0.080000, '[SYNTHETIC] fixed $8.50/mo, $0.0900/kWh, 8% tax',           20, TRUE
    UNION ALL SELECT 'RATE_PLAN', 'RES-3', 'Residential Budget Billing',  8.50, 0.105000, NULL,      0.080000, '[SYNTHETIC] fixed $8.50/mo, $0.1050/kWh, 8% tax',           30, TRUE
    -- Commercial plans (with demand charge)
    UNION ALL SELECT 'RATE_PLAN', 'COM-1', 'Commercial Standard Demand', 22.00, 0.105000, 8.500000, 0.085000, '[SYNTHETIC] fixed $22/mo, $0.1050/kWh, $8.50/kW, 8.5% tax', 40, TRUE
    UNION ALL SELECT 'RATE_PLAN', 'COM-2', 'Commercial Time-of-Use',     22.00, 0.095000, 9.000000, 0.085000, '[SYNTHETIC] fixed $22/mo, $0.0950/kWh, $9.00/kW, 8.5% tax', 50, TRUE
    UNION ALL SELECT 'RATE_PLAN', 'COM-3', 'Commercial Small Business',  15.00, 0.110000, NULL,      0.085000, '[SYNTHETIC] fixed $15/mo, $0.1100/kWh, no demand, 8.5% tax', 60, TRUE
    -- Industrial plans (with demand charge, lower energy rate)
    UNION ALL SELECT 'RATE_PLAN', 'IND-1', 'Industrial Large Load',      75.00, 0.085000, 12.000000, 0.070000, '[SYNTHETIC] fixed $75/mo, $0.0850/kWh, $12.00/kW, 7% tax',  70, TRUE
    UNION ALL SELECT 'RATE_PLAN', 'IND-2', 'Industrial Interruptible',   60.00, 0.075000, 10.000000, 0.070000, '[SYNTHETIC] fixed $60/mo, $0.0750/kWh, $10.00/kW, 7% tax',  80, TRUE
    -- Solar net-metering plan
    UNION ALL SELECT 'RATE_PLAN', 'SOL-1', 'Solar Net Metering',          8.50, 0.070000, NULL,      0.080000, '[SYNTHETIC] fixed $8.50/mo, $0.0700/kWh credit, 8% tax',    90, TRUE
) v(DOMAIN, CODE, CODE_LABEL, FIXED_RATE, ENERGY_RATE, DEMAND_RATE, TAX_RATE, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
WHERE NOT EXISTS (
    SELECT 1 FROM CODE_VALUE x WHERE x.DOMAIN = v.DOMAIN AND x.CODE = v.CODE
);

-- Repair pass: if rows exist but ATTRIBUTES is NULL (script ran before 03a),
-- update them now so the column is populated.
UPDATE CODE_VALUE
SET ATTRIBUTES = OBJECT_CONSTRUCT(
    'fixed',     CASE CODE
        WHEN 'RES-1' THEN 8.50   WHEN 'RES-2' THEN 8.50   WHEN 'RES-3' THEN 8.50
        WHEN 'COM-1' THEN 22.00  WHEN 'COM-2' THEN 22.00  WHEN 'COM-3' THEN 15.00
        WHEN 'IND-1' THEN 75.00  WHEN 'IND-2' THEN 60.00  WHEN 'SOL-1' THEN 8.50
    END,
    'energy',    CASE CODE
        WHEN 'RES-1' THEN 0.115000 WHEN 'RES-2' THEN 0.090000 WHEN 'RES-3' THEN 0.105000
        WHEN 'COM-1' THEN 0.105000 WHEN 'COM-2' THEN 0.095000 WHEN 'COM-3' THEN 0.110000
        WHEN 'IND-1' THEN 0.085000 WHEN 'IND-2' THEN 0.075000 WHEN 'SOL-1' THEN 0.070000
    END,
    'demand',    CASE CODE
        WHEN 'COM-1' THEN 8.500000  WHEN 'COM-2' THEN 9.000000
        WHEN 'IND-1' THEN 12.000000 WHEN 'IND-2' THEN 10.000000
        ELSE NULL
    END,
    'tax',       CASE CODE
        WHEN 'IND-1' THEN 0.070000 WHEN 'IND-2' THEN 0.070000
        WHEN 'COM-1' THEN 0.085000 WHEN 'COM-2' THEN 0.085000 WHEN 'COM-3' THEN 0.085000
        ELSE 0.080000
    END,
    'synthetic', TRUE
)
WHERE DOMAIN = 'RATE_PLAN'
  AND ATTRIBUTES IS NULL;

-- ===========================================================================
-- 9. DIST_ZONE — Distribution zone codes
-- ===========================================================================
INSERT INTO CODE_VALUE (DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
SELECT v.* FROM (
    SELECT 'DIST_ZONE', 'ZONE-N', 'Northern Zone', NULL, 'Northern distribution territory', 10, TRUE
    UNION ALL SELECT 'DIST_ZONE', 'ZONE-S', 'Southern Zone', NULL, 'Southern distribution territory', 20, TRUE
    UNION ALL SELECT 'DIST_ZONE', 'ZONE-E', 'Eastern Zone',  NULL, 'Eastern distribution territory',  30, TRUE
    UNION ALL SELECT 'DIST_ZONE', 'ZONE-W', 'Western Zone',  NULL, 'Western distribution territory',  40, TRUE
    UNION ALL SELECT 'DIST_ZONE', 'ZONE-C', 'Central Zone',  NULL, 'Central distribution territory',  50, TRUE
) v(DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
WHERE NOT EXISTS (
    SELECT 1 FROM CODE_VALUE x WHERE x.DOMAIN = v.DOMAIN AND x.CODE = v.CODE
);

-- ===========================================================================
-- 10. RATE_CLASS — Energy account rate classification
-- ===========================================================================
INSERT INTO CODE_VALUE (DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
SELECT v.* FROM (
    SELECT 'RATE_CLASS', 'RESIDENTIAL',     'Residential',       NULL, 'Single-family residential account', 10, TRUE
    UNION ALL SELECT 'RATE_CLASS', 'SMALL_COMMERCIAL',  'Small Commercial',  NULL, 'Commercial < 50 kW demand',         20, TRUE
    UNION ALL SELECT 'RATE_CLASS', 'MEDIUM_COMMERCIAL', 'Medium Commercial', NULL, 'Commercial 50–500 kW demand',       30, TRUE
    UNION ALL SELECT 'RATE_CLASS', 'LARGE_INDUSTRIAL',  'Large Industrial',  NULL, 'Industrial > 500 kW demand',        40, TRUE
    UNION ALL SELECT 'RATE_CLASS', 'SOLAR_NET',         'Solar Net Meter',   NULL, 'Solar/renewable account',           50, TRUE
) v(DOMAIN, CODE, CODE_LABEL, ATTRIBUTES, DESCRIPTION, DISPLAY_ORDER, IS_ACTIVE)
WHERE NOT EXISTS (
    SELECT 1 FROM CODE_VALUE x WHERE x.DOMAIN = v.DOMAIN AND x.CODE = v.CODE
);

-- ===========================================================================
-- POST-SEED VALIDATION (Issue #7)
-- Every assertion must PASS before running script 06.
-- ===========================================================================

-- Check 1: Total domain/code count
SELECT 'PS-001' AS CHECK_ID,
    'Total CODE_VALUE row count >= 43' AS DESCRIPTION,
    CASE WHEN COUNT(*) >= 43 THEN 'PASS' ELSE 'FAIL' END AS STATUS,
    COUNT(*) AS ROW_COUNT
FROM CODE_VALUE;
-- Expected: PASS, 43 rows

-- Check 2: RATE_PLAN rows have ATTRIBUTES (not null, valid VARIANT)
SELECT 'PS-002' AS CHECK_ID,
    'All RATE_PLAN rows have non-null ATTRIBUTES' AS DESCRIPTION,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS,
    COUNT(*) AS ROWS_WITH_NULL_ATTRIBUTES
FROM CODE_VALUE
WHERE DOMAIN = 'RATE_PLAN' AND ATTRIBUTES IS NULL;
-- Expected: PASS, 0

-- Check 3: CODE_LABEL for RATE_PLAN contains no JSON (must not start with '{')
SELECT 'PS-003' AS CHECK_ID,
    'RATE_PLAN CODE_LABEL contains no JSON braces' AS DESCRIPTION,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS,
    COUNT(*) AS ROWS_WITH_JSON_IN_LABEL
FROM CODE_VALUE
WHERE DOMAIN = 'RATE_PLAN'
  AND (CODE_LABEL LIKE '{%' OR CODE_LABEL LIKE '%"%:%');
-- Expected: PASS, 0

-- Check 4: All required rate keys present in ATTRIBUTES
SELECT 'PS-004' AS CHECK_ID,
    'All RATE_PLAN ATTRIBUTES contain fixed, energy, tax keys' AS DESCRIPTION,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS,
    COUNT(*) AS ROWS_MISSING_RATE_KEYS
FROM CODE_VALUE
WHERE DOMAIN = 'RATE_PLAN'
  AND IS_ACTIVE = TRUE
  AND (   ATTRIBUTES['fixed']  IS NULL
       OR ATTRIBUTES['energy'] IS NULL
       OR ATTRIBUTES['tax']    IS NULL);
-- Expected: PASS, 0

-- Check 5: Valid rates convert to non-null DECIMAL via TRY_TO_DECIMAL
SELECT 'PS-005' AS CHECK_ID,
    'RATE_PLAN ATTRIBUTES rates convert to non-null DECIMAL' AS DESCRIPTION,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS STATUS,
    COUNT(*) AS ROWS_WHERE_RATE_CONVERTS_TO_NULL
FROM CODE_VALUE
WHERE DOMAIN = 'RATE_PLAN'
  AND IS_ACTIVE = TRUE
  AND (  TRY_TO_DECIMAL(ATTRIBUTES['fixed']::STRING,  10, 2) IS NULL
      OR TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6) IS NULL
      OR TRY_TO_DECIMAL(ATTRIBUTES['tax']::STRING,    10, 6) IS NULL);
-- Expected: PASS, 0

-- Check 6: JSON-null demand is correctly stored (demand key present, value null)
--   Plans with no demand component must have ATTRIBUTES['demand'] = JSON null,
--   which evaluates to NULL in TRY_TO_DECIMAL (per ICA MU-AC-09).
SELECT 'PS-006' AS CHECK_ID,
    'No-demand RATE_PLAN rows have ATTRIBUTES demand = JSON null' AS DESCRIPTION,
    CASE WHEN SUM(CASE
        WHEN ATTRIBUTES['demand']::STRING IS NULL THEN 1 ELSE 0 END) >= 5 THEN 'PASS'
    ELSE 'FAIL' END AS STATUS,
    SUM(CASE WHEN ATTRIBUTES['demand']::STRING IS NULL THEN 1 ELSE 0 END) AS NO_DEMAND_ROWS
FROM CODE_VALUE
WHERE DOMAIN = 'RATE_PLAN' AND IS_ACTIVE = TRUE;
-- Expected: PASS (RES-1, RES-2, RES-3, COM-3, SOL-1 = 5 plans have null demand)

-- Check 7: End-to-end calculation for RES-1 (500 kWh, no demand)
--   fixed=8.50, energy=0.115000, demand=null, tax=0.080000
--   Energy charge = ROUND(500 × 0.115000, 2) = 57.50
--   Subtotal      = 8.50 + 57.50 + 0         = 66.00
--   Tax           = ROUND(66.00 × 0.080000, 2) = 5.28
--   Total         = 66.00 + 5.28              = 71.28
SELECT 'PS-007' AS CHECK_ID,
    'End-to-end RES-1 charge calculation (500 kWh)' AS DESCRIPTION,
    CASE WHEN
        TRY_TO_DECIMAL(ATTRIBUTES['fixed']::STRING,  10, 2) IS NOT NULL AND
        TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6) IS NOT NULL AND
        ROUND(500 * TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6), 2) = 57.50 AND
        ROUND((TRY_TO_DECIMAL(ATTRIBUTES['fixed']::STRING, 10, 2)
               + ROUND(500 * TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6), 2))
              * TRY_TO_DECIMAL(ATTRIBUTES['tax']::STRING, 10, 6), 2) = 5.28
    THEN 'PASS' ELSE 'FAIL' END AS STATUS,
    TRY_TO_DECIMAL(ATTRIBUTES['fixed']::STRING, 10, 2)        AS FIXED_RATE,
    TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6)       AS ENERGY_RATE,
    ROUND(500 * TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6), 2)  AS ENERGY_CHARGE,
    TRY_TO_DECIMAL(ATTRIBUTES['fixed']::STRING, 10, 2)
    + ROUND(500 * TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6), 2) AS SUBTOTAL,
    ROUND((TRY_TO_DECIMAL(ATTRIBUTES['fixed']::STRING, 10, 2)
           + ROUND(500 * TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6), 2))
          * TRY_TO_DECIMAL(ATTRIBUTES['tax']::STRING, 10, 6), 2)           AS TAX,
    TRY_TO_DECIMAL(ATTRIBUTES['fixed']::STRING, 10, 2)
    + ROUND(500 * TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6), 2)
    + ROUND((TRY_TO_DECIMAL(ATTRIBUTES['fixed']::STRING, 10, 2)
             + ROUND(500 * TRY_TO_DECIMAL(ATTRIBUTES['energy']::STRING, 10, 6), 2))
            * TRY_TO_DECIMAL(ATTRIBUTES['tax']::STRING, 10, 6), 2)         AS TOTAL
FROM CODE_VALUE
WHERE DOMAIN = 'RATE_PLAN' AND CODE = 'RES-1';
-- Expected: PASS — FIXED=8.50, ENERGY_RATE=0.115000, ENERGY_CHARGE=57.50,
--           SUBTOTAL=66.00, TAX=5.28, TOTAL=71.28

-- ===========================================================================
-- VARIANT BRACKET SYNTAX TEST
-- Confirms ATTRIBUTES['key']::STRING notation works correctly in this session.
-- Run this before the post-seed checks if any syntax doubt exists.
-- ===========================================================================
-- PS-SYNTAX-01: bracket notation on an inline PARSE_JSON literal
SELECT
    TRY_TO_DECIMAL(
        PARSE_JSON('{"fixed":8.50}')['fixed']::STRING,
        10,
        2
    ) AS FIXED_RATE;
-- Expected: 8.50
-- If this returns NULL or errors, the Snowflake session/version does not support
-- bracket VARIANT path syntax — do not proceed until resolved.

-- Summary
SELECT DOMAIN, COUNT(*) AS CODE_COUNT
FROM CODE_VALUE
GROUP BY DOMAIN
ORDER BY DOMAIN;
-- Expected domains and counts:
--   ACCT_STATUS(5), CONTACT_TYPE(5), CUST_TYPE(3), DIST_ZONE(5),
--   METER_TYPE(3), PAYMENT_METHOD(3), RATE_CLASS(5), RATE_PLAN(9),
--   READ_TYPE(2), SERVICE_TYPE(3)  = 43 total rows
